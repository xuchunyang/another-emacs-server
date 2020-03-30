# An Emacs server built on HTTP and JSON

The builtin Emacs server is built on Unix domain socket, `another-emacs-server`
is builton HTTP and JSON. Because the response is JSON, it's easy and reliable
for other tool to consume.

## Usage

Run `M-x another-emacs-server` to start the server. Send

- `{"eval": "expr"}` to eval an expression
- `{"file": ["filename1", "filename2", ...]}` to open files

For example,

    ~ $ curl -s -d '{"eval": "emacs-version"}' -H "Content-Type: application/json" localhost:7777 | jq
    {
      "result": "27.0.90"
    }

    ~ $ curl -s -d '{"file": ["/etc/hosts"]}' -H "Content-Type: application/json" localhost:7777 | jq
    {
      "result": "OK"
    }

## Requires

- Emacs 25.1
- web-server 20200312
