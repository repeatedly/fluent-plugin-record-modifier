# Output filter plugin for modifying each event record

Adding arbitary field to event record without custmizing existence plugin.

For example, generated event from *in_tail* doesn't contain "hostname" of running machine.
In this case, you can use *record_modifier* to add "hostname" field to event record.

## Installation

Use RubyGems:

    gem install fluent-plugin-record-modifier

## Configuration

    <match pattern>
      type record_modifier
      tag foo.filtered

      gen_host ${hostname}
      foo bar
    </match>

If following record is passed:

```js
{"message":"hello world!"}
```

then you got new record like below:

```js
{"message":"hello world!", "gen_host":"oreore-mac.local", "foo":"bar"}
```

### char_encoding

Fluentd including some plugins treats the logs as a BINARY by default to forward.
But an user sometimes processes the logs depends on their requirements, e.g. handling char encoding correctly.

`char_encoding` parameter is useful for this case.

```conf
<match pattern>
  type record_modifier

  # set UTF-8 encoding information to string.
  char_encoding utf-8

  # change char encoding from 'UTF-8' to 'EUC-JP'
  char_encoding utf-8:euc-jp
</match>
```

### Mixins

* [SetTagKeyMixin](https://github.com/fluent/fluentd/blob/master/lib/fluent/mixin.rb#L181)
* [fluent-mixin-config-placeholders](https://github.com/tagomoris/fluent-mixin-config-placeholders)

## TODO

* Adding following features if needed

    * Use HandleTagNameMixin to keep original tag

    * Remove record field

    * Replace record value


## Copyright

<table>
  <tr>
    <td>Author</td><td>Masahiro Nakagawa <repeatedly@gmail.com></td>
  </tr>
  <tr>
    <td>Copyright</td><td>Copyright (c) 2013- Masahiro Nakagawa</td>
  </tr>
  <tr>
    <td>License</td><td>MIT License</td>
  </tr>
</table>
