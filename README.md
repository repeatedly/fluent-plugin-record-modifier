# Output filter plugin for modifying each event record

Adding arbitary field to event record without custmizing existence plugin.

For example, generated event from *in_tail* doesn't contain "hostname" of running machine.
In this case, you can use *record_modifier* to add "hostname" field to event record.

## Installation

Use RubyGems:

    gem install fluentd-plugin-record-modifier

## Configuration

    <filter pattern>
      type record_modifier
      tag foo.filtered

      gen_host ${Socket.gethostname.chomp}
      foo bar
    </filter>

If following record is passed:

```js
{"message":"hello world!"}
```

then you got new record like below:

```js
{"message":"hello world!", "gen_host":"oreore-mac.local", "foo":"bar"}
```

### Simulation of SetTagKeyMixin and SetTimeKeyMixin

In v11, Mixins are deleted. But we can realized same result using *record_modifier*.
You can specifiy following configurations:

* include_tag_key
* tag_key
* include_time_key
* time_key
* time_format
* localtime
* utc
* time_as_epoch (include time as epoch integer, not formatted string)

## TODO

* Adding following features if needed

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
