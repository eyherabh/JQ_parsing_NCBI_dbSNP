# JQ_parsing_NCBI_dbSNP
Using jq for parsing NCBI dbsnp json files


## Listing all top-level keys

The advice given by [[1]] does not work for the `refsnp*.json` files because each record is a separate object, as opposed to an element of an array. Instead, consider using the following (requires jq >=1.5)
```jq
[inputs] | add | keys
```




## References

[1]: https://github.com/stedolan/jq/wiki/Cookbook#list-keys-used-in-any-object-in-a-list

1. https://github.com/stedolan/jq/wiki/Cookbook#list-keys-used-in-any-object-in-a-list
