# ao-https-with-header

Mock HTTPS server that requires a client certificate, for testing mTLS and the
header-based authentication object (`/secure` needs `X-Secure-ID: very-very-secure-id`).
Source: https://github.com/brightsec/mock-servers/tree/master/apps/ao-https-with-header

## Default mode

The generic `simple-service` deployment with the image's built-in certificates.
It accepts only the built-in `alice@example.com` client certificate.

## NLB mode: your own client CA

ingress-nginx terminates TLS, so client certificates never reach the server
through it. In NLB mode the server is exposed through an L4 AWS NLB on port 443,
which passes TLS through:

- The server terminates TLS itself, with the certificate from the
  `kubernetes.io/tls` secret `nlb.tlsSecretName` (default `nlbwildcard`,
  `*.nlb.brokencrystals.nexploit.app`).
- It trusts the client CAs from `clientCA`.
- external-dns creates the record `<release>.nlb.brokencrystals.nexploit.app`.

```sh
helm install <release> vulnerable-apps/ao-https-with-header -n distributor \
  --set nlb.enabled=true --set simple-service.enabled=false \
  --set-file clientCA=ca-chain.pem
```

To accept only specific client certificates (for example a smart card's,
self-signed or not) regardless of their issuer, put the certificates
themselves into `clientCA`:

```sh
helm install <release> vulnerable-apps/ao-https-with-header -n distributor \
  --set nlb.enabled=true --set simple-service.enabled=false \
  --set clientCertCheck=exact --set-file clientCA=client-certs.pem
```

The client must still prove it holds the private key. Any other certificate is
dropped right after the TLS handshake, so the client sees a connection error.

| Value               | Default                                       | Description                                                                                                                                                                                                   |
| ------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `clientCA`          | built-in `MyCompany Root CA`                  | PEM bundle of the CAs whose client certificates are accepted. Include every intermediate **and** the root: the server rejects a chain that ends at an intermediate, and clients send only their own certificate. |
| `clientCertPinning` | `false` with `clientCA`, otherwise `true`     | `true`: only the built-in `alice@example.com` certificate. `false`: any certificate issued by `clientCA`. Needs an image with `CLIENT_CERT_PINNING` support; older images always pin and answer 403.          |
| `clientCertCheck`   | `ca`                                          | `ca`: the client certificate must be issued by a CA in `clientCA`. `exact`: `clientCA` lists the accepted client certificates themselves, and any other certificate, even from the same CA, is rejected; `clientCertPinning` is then ignored. Needs an image with `CLIENT_CERT_CHECK` support. |
| `nlb.image`         | `ghcr.io/brightsec/ao-https-with-header:latest` | Server image.                                                                                                                                                                                                  |
| `nlb.tlsSecretName` | `nlbwildcard`                                 | Server certificate secret; it must cover `<release>.nlb.brokencrystals.nexploit.app`.                                                                                                                         |

The service is available at `https://<release>.nlb.brokencrystals.nexploit.app`
about 4 to 6 minutes after the install, once the DNS record exists and the NLB
serves traffic stably.

| Response                                                 | Meaning                                                                   |
| -------------------------------------------------------- | ------------------------------------------------------------------------- |
| `GET /` → 200 `Certificate is valid!`                    | The client certificate was issued by `clientCA`.                          |
| `GET /secure` → 200 `Welcome!`                           | The same, plus the `X-Secure-ID` header.                                  |
| 403 `Client data in certificate does not match allowed!` | mTLS passed, but pinning is on and the certificate is not alice's.         |
| TLS error, no HTTP response                              | No client certificate, or one that `clientCA` did not issue.              |
| Connection error, no HTTP response (`exact`)             | No client certificate, or one that is not in `clientCA`.                  |

## Test

```sh
helm test <release> -n distributor --timeout 700s --logs
```

The test pod:

1. resolves the name through the Route53 authoritative servers of `nexploit.app`;
2. waits until every NLB IP completes a TLS handshake 12 times in a row;
3. checks the server certificate for the public name;
4. checks that the server requests client certificates from exactly the CAs in `clientCA`, which proves the passthrough;
5. checks that a request without a client certificate is rejected.

## Remove

```sh
helm uninstall <release> -n distributor
```

The NLB and the DNS record are deleted automatically.
