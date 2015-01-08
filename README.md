# fluent-plugin-dos_block_acl [![Build Status](https://secure.travis-ci.org/toyama0919/fluent-plugin-dos_block_acl.png?branch=master)](http://travis-ci.org/toyama0919/fluent-plugin-dos_block_acl)

access block by aws network acl.

aggregate unit is time_slice_format.

## Installation
```
fluent-gem install fluent-plugin-dos_block_acl
```

## Examples(more than 10000 access per hour)
```
<match dos_block_acl.exsample>
  type dos_block_acl
  network_acl_id acl-xxxxxxx
  ip_address_key ip_address
  dos_threshold 10000
  buffer_chunk_limit 256m
  region ap-northeast-1
  deny_rule_numbers_range 1..10
  time_slice_format %Y%m%d_%H
  buffer_path /tmp/dos_block_acl_hourly*.log
  state_file /var/log/td-agent/buffer/dos_block_acl_state.log
</match>
```

## Examples(more than 100000 access per day)
```
<match dos_block_acl.exsample>
  type dos_block_acl
  network_acl_id acl-xxxxxxx
  ip_address_key ip_address
  dos_threshold 10000
  buffer_chunk_limit 256m
  region ap-northeast-1
  deny_rule_numbers_range 11..18
  time_slice_format %Y%m%d
  buffer_path /tmp/dos_block_acl_daily*.log
  state_file /var/log/td-agent/buffer/dos_block_acl_state.log
</match>
```

## parameter

|param    | default|exsample|
|--------|--------|--------|
|network_acl_id||acl-xxxxxx|
|dryrun| false|true|
|ip_address_key||ip_address|
|dos_threshold||1000|
|time_slice_format |%Y%m%d|%Y%m%d_%H|
|aws_key_id| nil||
|aws_sec_key| nil||
|region| nil|ap-northeast-1|
|white_list| '127.0.0.1'|127.0.0.1,192.168.0.1,192.168.0.2|
|deny_rule_numbers_range| '1..18'||
|state_file| nil|/var/log/td-agent/dos_block_acl_state.log|



## Notes

default network acl entry limit is 20.([see](http://docs.aws.amazon.com/ja_jp/AmazonVPC/latest/UserGuide/VPC_Appendix_Limits.html))


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new [Pull Request](../../pull/new/master)

## Information

* [Homepage](https://github.com/toyama0919/fluent-plugin-dos_block_acl)
* [Issues](https://github.com/toyama0919/fluent-plugin-dos_block_acl/issues)
* [Documentation](http://rubydoc.info/gems/fluent-plugin-dos_block_acl/frames)
* [Email](mailto:toyama0919@gmail.com)

## Copyright

Copyright (c) 2015 Hiroshi Toyama

