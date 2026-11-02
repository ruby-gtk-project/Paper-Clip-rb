# Encrypted fixtures

Four copies of the same two-object PDF, encrypted by `qpdf` with the user
password `secret` and the owner password `owner`, one per revision of the
standard security handler that a consumer-written PDF uses:

| File | /V | /R | Algorithm |
|---|---:|---:|---|
| `encrypted-rc4-40.pdf` | 1 | 2 | RC4, 40-bit |
| `encrypted-rc4-128.pdf` | 2 | 3 | RC4, 128-bit |
| `encrypted-aes128.pdf` | 4 | 4 | AES-128 (`/CF /StdCF /CFM /AESV2`) |
| `encrypted-aes256.pdf` | 5 | 6 | AES-256 (`/CF /StdCF /CFM /AESV3`) |

These are committed rather than generated because generating them would mean
implementing the *encryption* half of Algorithms 2 to 7 — the half the port
does not have and does not need — and a fixture produced by the code under
test proves nothing about it. They were produced by a third-party tool:

```sh
qpdf --allow-weak-crypto --encrypt --user-password=secret \
     --owner-password=owner --bits=40 -- plain.pdf encrypted-rc4-40.pdf
```

with `--bits=128 --use-aes=n`, `--bits=128 --use-aes=y` and `--bits=256` for
the other three. `plain.pdf` is the file `PdfFixtures.classic` writes.

The passwords are in this file on purpose: there is nothing behind them but
the words "Secret Title".
