# xmpp.new

Provides `xmpp.new` installer as an archive.

To install from hex, run:

```
$ mix archive.install hex xmpp_new 0.4.0
```

To build and install it locally, ensure any previous archive versions are removed:

```
$ mix archive.uninstall xmpp_new
```

Then run:

```
$ cd installer
$ MIX_ENV=prod mix do archive.build, archive.install
```
