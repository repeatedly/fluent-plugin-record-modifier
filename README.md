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
