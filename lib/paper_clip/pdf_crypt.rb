# frozen_string_literal: true

require 'digest'
require 'openssl'
require 'securerandom'

module PaperClip
  # PdfCrypt is the PDF standard security handler: it turns a password into
  # the file encryption key and decrypts or encrypts the strings and streams
  # an encrypted document holds.
  #
  # Upstream never writes this, because Poppler has it. This port has no
  # Poppler binding, so the handler is here, covering every revision a
  # consumer-written PDF uses: R2 and R3 (RC4, 40- and 128-bit), R4 (RC4 or
  # AES-128 through /CF /StdCF), and R5 and R6 (AES-256).
  #
  # RC4 is implemented in Ruby rather than through OpenSSL: OpenSSL ships
  # without it on this platform (`OpenSSL::Cipher.new('RC4')` raises), and a
  # 40-bit PDF from 2003 still has to open.
  #
  # The entry point is `open`, which returns nil rather than raising when the
  # password does not validate — Document turns that into EncryptedError, so
  # the window can tell "ask for a password" apart from "that password was
  # wrong" by whether it had one to try.
  class PdfCrypt
    # The 32-byte padding string of PDF 32000-1 Algorithm 2, which is what
    # makes a short password a 32-byte one.
    PAD = [
      0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41,
      0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
      0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
      0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
    ].pack('C*').freeze

    # Appended to an object's key material before the MD5 in Algorithm 1 when
    # the crypt filter is AESV2. The bytes spell "sAlT".
    AES_SALT = "\x73\x41\x6C\x54".b.freeze

    AES_BLOCK = 16
    ZERO_IV = ("\0" * AES_BLOCK).b.freeze

    # /CF /StdCF /CFM, which names the algorithm V4 and V5 documents use.
    IDENTITY = 'Identity'
    RC4_FILTER = 'V2'
    AES128_FILTER = 'AESV2'
    AES256_FILTER = 'AESV3'

    # The three digests Algorithm 2.B rotates between, indexed by the
    # remainder it computes.
    HASH_2B_DIGESTS = [Digest::SHA256, Digest::SHA384, Digest::SHA512].freeze

    attr_reader :revision, :version

    # `dict` is the resolved /Encrypt dictionary, `file_id` the raw bytes of
    # the first element of the trailer's /ID array, and `password` what the
    # user typed, or nil for the empty password Poppler tries first.
    #
    # Returns nil when neither the user nor the owner password validates.
    def self.open(dict, file_id, password = nil)
      if standard?(dict)
        new(dict, file_id).then { |crypt| crypt.unlock(password.to_s) }
      end
    end

    def self.standard?(dict)
      dict.is_a?(Hash) && dict['Filter'].to_s == 'Standard'
    end

    # RC4 is its own inverse, so one method serves both directions.
    def self.rc4(key, data)
      state = key_schedule(key)
      i = 0
      j = 0
      data.b.bytes.map do |byte|
        i = (i + 1) & 0xFF
        j = (j + state[i]) & 0xFF
        state[i], state[j] = state[j], state[i]
        byte ^ state[(state[i] + state[j]) & 0xFF]
      end.pack('C*')
    end

    def self.key_schedule(key)
      key.b.bytes.then do |bytes|
        (0..255).to_a.tap do |state|
          j = 0
          256.times do |i|
            j = (j + state[i] + bytes[i % bytes.length]) & 0xFF
            state[i], state[j] = state[j], state[i]
          end
        end
      end
    end

    def initialize(dict, file_id)
      @dict = dict
      @file_id = file_id.to_s.b
      @version = integer(dict['V'], 0)
      @revision = integer(dict['R'], 0)
      @permissions = integer(dict['P'], 0)
      @owner_key = raw(dict['O'])
      @user_key = raw(dict['U'])
      @owner_encrypted = raw(dict['OE'])
      @user_encrypted = raw(dict['UE'])
      @encrypt_metadata = dict.fetch('EncryptMetadata', true) != false
      @key = nil
    end

    # True when the /Metadata stream is left in the clear, which an archival
    # writer does so a search indexer can read it without the password.
    def encrypt_metadata? = @encrypt_metadata

    def key_bytes = @key.bytesize

    # Returns self when the password opens the file and nil when it does not,
    # so `PdfCrypt.open` can be used in a conditional.
    def unlock(password)
      file_key(password).then do |key|
        if key
          @key = key
          self
        end
      end
    end

    def decrypt_string(data, number, generation)
      transform(
        data,
        number,
        generation,
        string_filter,
        decrypt: true,
      )
    end

    def encrypt_string(data, number, generation)
      transform(
        data,
        number,
        generation,
        string_filter,
        decrypt: false,
      )
    end

    def decrypt_stream(data, number, generation)
      transform(
        data,
        number,
        generation,
        stream_filter,
        decrypt: true,
      )
    end

    def encrypt_stream(data, number, generation)
      transform(
        data,
        number,
        generation,
        stream_filter,
        decrypt: false,
      )
    end

    # The filters V4 and V5 name in /CF; V1 to V3 are RC4 throughout.
    def stream_filter = @stream_filter ||= named_filter(@dict['StmF'])
    def string_filter = @string_filter ||= named_filter(@dict['StrF'])

    private

      def integer(value, fallback)
        if value.is_a?(Integer)
          value
        else
          fallback
        end
      end

      # The parser hands back a decoded Ruby string with the original bytes
      # attached; /O, /U, /OE and /UE are key material and only the bytes
      # will do.
      def raw(value)
        if value.respond_to?(:raw)
          value.raw
        else
          value.to_s.b
        end
      end

      def named_filter(name)
        if @version >= 4
          crypt_filter(name.to_s)
        else
          RC4_FILTER
        end
      end

      def crypt_filter(name)
        if name == IDENTITY
          IDENTITY
        else
          filter_dictionary(name).then { |cf| cf.fetch('CFM', RC4_FILTER).to_s }
        end
      end

      def filter_dictionary(name)
        @dict['CF'].then do |filters|
          if filters.is_a?(Hash) && filters[name].is_a?(Hash)
            filters[name]
          else
            {}
          end
        end
      end

      # --- Key derivation ---------------------------------------------------

      def file_key(password)
        if @revision >= 5
          modern_key(password)
        else
          legacy_key(password)
        end
      end

      # Algorithm 2 for the key, then Algorithm 6 to check it against /U; a
      # password that is not the user's is tried as the owner's through
      # Algorithm 7.
      def legacy_key(password)
        candidate(password).then do |key|
          if key
            key
          else
            candidate(recovered_user_password(password))
          end
        end
      end

      def candidate(password)
        if password
          derive_legacy_key(password).then do |key|
            if valid_user_key?(key)
              key
            end
          end
        end
      end

      def derive_legacy_key(password)
        Digest::MD5.new.tap do |md5|
          md5 << padded(password)
          md5 << @owner_key
          md5 << [@permissions].pack('l<')
          md5 << @file_id
          if metadata_marker?
            md5 << "\xFF\xFF\xFF\xFF".b
          end
        end.digest.then { |digest| spin(digest[0, legacy_key_length]) }
      end

      # R4 and later mix in four 0xFF bytes when the metadata is left
      # unencrypted, so the key of such a file differs from the key of the
      # same file with the flag unset.
      def metadata_marker? = @revision >= 4 && !@encrypt_metadata

      # Algorithm 2 step 5: fifty further MD5 rounds for R3 and up.
      def spin(key)
        if @revision >= 3
          50.times.reduce(key) { |current, _| Digest::MD5.digest(current)[0, key.bytesize] }
        else
          key
        end
      end

      def legacy_key_length
        if @revision == 2
          5
        else
          declared_key_bits / 8
        end
      end

      # /Length is in bits on the /Encrypt dictionary and in bytes on a crypt
      # filter, and writers disagree about which; anything at or under 40 is
      # read as bytes because no key is 40 bits long in a V4 file.
      def declared_key_bits
        integer(@dict['Length'], 128).then do |length|
          if length <= 40
            length * 8
          else
            length
          end
        end
      end

      def padded(password) = (password.to_s.b + PAD)[0, 32]

      # Algorithm 6 for R2, and its R3+ form which only compares the first
      # sixteen bytes because the rest is padded with arbitrary data.
      def valid_user_key?(key)
        if @revision == 2
          self.class.rc4(key, PAD) == @user_key[0, 32]
        else
          computed_user_key(key) == @user_key[0, 16]
        end
      end

      # Algorithm 5: MD5 of the pad and the file ID, then twenty RC4 rounds
      # with the key XORed by the round number.
      def computed_user_key(key)
        Digest::MD5.digest(PAD + @file_id).then do |seed|
          19.times.reduce(self.class.rc4(key, seed)) do |data, round|
            self.class.rc4(xor_key(key, round + 1), data)
          end
        end[0, 16]
      end

      def xor_key(key, round)
        key.b.bytes.map { |byte| byte ^ round }.pack('C*')
      end

      # Algorithm 7: the owner password decrypts /O back into the user
      # password, which is then checked the ordinary way.
      def recovered_user_password(password)
        owner_derived_key(password).then do |key|
          if @revision == 2
            self.class.rc4(key, @owner_key)
          else
            19.downto(0).reduce(@owner_key) { |data, round| self.class.rc4(xor_key(key, round), data) }
          end
        end
      end

      def owner_derived_key(password)
        Digest::MD5.digest(padded(password)).then do |digest|
          spin(digest[0, legacy_key_length])
        end
      end

      # --- AES-256: R5 and R6 ------------------------------------------------

      # The 48-byte /U is hash, validation salt, key salt; /O is the same
      # shape but hashed over /U as well, which is what ties an owner
      # password to one particular file.
      def modern_key(password)
        modern_user_key(password) || modern_owner_key(password)
      end

      def modern_user_key(password)
        if hash_2b(password, @user_key[32, 8], '') == @user_key[0, 32]
          unwrap(@user_encrypted, hash_2b(password, @user_key[40, 8], ''))
        end
      end

      def modern_owner_key(password)
        @user_key[0, 48].then do |user_data|
          if hash_2b(password, @owner_key[32, 8], user_data) == @owner_key[0, 32]
            unwrap(@owner_encrypted, hash_2b(password, @owner_key[40, 8], user_data))
          end
        end
      end

      # The wrapped file key is AES-256-CBC with a zero IV and no padding.
      def unwrap(wrapped, intermediate)
        OpenSSL::Cipher.new('AES-256-CBC').then do |cipher|
          cipher.decrypt
          cipher.padding = 0
          cipher.key = intermediate
          cipher.iv = ZERO_IV
          cipher.update(wrapped.to_s) + cipher.final
        end
      rescue OpenSSL::Cipher::CipherError
        nil
      end

      # Algorithm 2.B. R5 stops at the first SHA-256; R6 runs the hardening
      # loop, whose stop condition is the last byte of the AES output.
      def hash_2b(password, salt, user_data)
        Digest::SHA256.digest(password.to_s.b + salt.to_s.b + user_data.to_s.b).then do |first|
          if @revision == 5
            first
          else
            harden(password.to_s.b, first, user_data.to_s.b)
          end
        end
      end

      def harden(password, first, user_data)
        key = first
        round = 0
        loop do
          block = (password + key + user_data) * 64
          encrypted = aes_cbc_no_pad(key[0, 16], key[16, 16], block)
          key = HASH_2B_DIGESTS[sum_of_first_block(encrypted) % 3].digest(encrypted)
          round += 1
          if round >= 64 && encrypted.getbyte(-1) <= round - 32
            break
          end
        end
        key[0, 32]
      end

      def sum_of_first_block(encrypted)
        encrypted[0, 16].b.bytes.sum
      end

      def aes_cbc_no_pad(key, iv, data)
        OpenSSL::Cipher.new('AES-128-CBC').then do |cipher|
          cipher.encrypt
          cipher.padding = 0
          cipher.key = key
          cipher.iv = iv
          cipher.update(data) + cipher.final
        end
      end

      # --- Per-object transformation ----------------------------------------

      def transform(data, number, generation, filter, decrypt:)
        case filter
        when IDENTITY then data.to_s.b
        when AES256_FILTER then aes(data, @key, decrypt: decrypt)
        when AES128_FILTER then aes(data, object_key(number, generation, aes: true), decrypt: decrypt)
        else self.class.rc4(object_key(number, generation, aes: false), data)
        end
      end

      # Algorithm 1: the file key, the object and generation numbers, and for
      # AESV2 the salt, hashed down to at most sixteen bytes.
      def object_key(number, generation, aes:)
        Digest::MD5.new.tap do |md5|
          md5 << @key
          md5 << [number].pack('V')[0, 3]
          md5 << [generation].pack('v')[0, 2]
          if aes
            md5 << AES_SALT
          end
        end.digest[0, [@key.bytesize + 5, 16].min]
      end

      # A PDF AES string is its own random IV followed by CBC ciphertext with
      # PKCS#5 padding.
      def aes(data, key, decrypt:)
        if decrypt
          aes_decrypt(data.to_s.b, key)
        else
          aes_encrypt(data.to_s.b, key)
        end
      end

      def aes_decrypt(data, key)
        if data.bytesize > AES_BLOCK
          run_cipher(
            aes_name(key),
            :decrypt,
            key,
            data[0, AES_BLOCK],
            data[AES_BLOCK..],
          )
        else
          ''.b
        end
      end

      def aes_encrypt(data, key)
        SecureRandom.bytes(AES_BLOCK).then do |iv|
          iv + run_cipher(
            aes_name(key),
            :encrypt,
            key,
            iv,
            data,
          )
        end
      end

      def run_cipher(name, direction, key, iv, data)
        OpenSSL::Cipher.new(name).then do |cipher|
          cipher.public_send(direction)
          cipher.key = key
          cipher.iv = iv
          cipher.update(data) + cipher.final
        end
      rescue OpenSSL::Cipher::CipherError
        ''.b
      end

      def aes_name(key)
        if key.bytesize == 32
          'AES-256-CBC'
        else
          'AES-128-CBC'
        end
      end
  end
end
