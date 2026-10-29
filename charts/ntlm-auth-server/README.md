# ntlm-auth-server

Mock server for testing NTLM authentication clients.
Source: https://github.com/brightsec/mock-servers/tree/master/apps/ntlm-auth-server

NTLM authenticates the TCP connection, so the server is exposed through an AWS NLB
on port 80 (plain HTTP) instead of ingress-nginx, which pools upstream connections
and breaks the handshake. external-dns creates the record
`<release>.nlb.brokencrystals.nexploit.app` pointing to the NLB.

## Deploy

```sh
helm install <release> vulnerable-apps/ntlm-auth-server -n distributor
```

Custom users (optional, defaults are `john/password` and `mydomain\jane/password`):

```sh
helm install <release> vulnerable-apps/ntlm-auth-server -n distributor \
  --set-string 'ntlmUsers=[{"username":"alice"\,"password":"s3cret"\,"domain":"corp"}]'
```

The service is available at `http://<release>.nlb.brokencrystals.nexploit.app`
(protected page: `/protected`) about 4 minutes after the install: ~2 minutes for
the DNS record and ~2 more minutes for the NLB to serve traffic stably.

## Test

```sh
helm test <release> -n distributor --timeout 600s --logs
```

The test pod:

1. resolves the name via the Route53 authoritative servers of `nexploit.app`,
   bypassing the cluster DNS, and waits up to `tests.timeoutSeconds` for the record;
2. waits until every NLB IP answers `GET /` 12 times in a row with a 5 second step;
3. checks `/protected`: 401 without auth and with a wrong password, and 200 for the
   default users when `ntlmUsers` is not set.

The test pod is deleted automatically after the run; `--logs` prints its output.

## Remove

```sh
helm uninstall <release> -n distributor
```

The NLB and the DNS record are deleted automatically.
