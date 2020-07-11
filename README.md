# Using JQ by parsing NCBI dbSNP

Questions and answers about 

+ the application of JQ to parse NCBI dbSNP, 
+ the structure and content of NCBI dbSNP json files, and 
+ the correctness of the demo parsers provided by the NCBI repository.

## Listing all top-level keys

The advice given by [[1]] works for arrays of JSON objects. However, it does not work for the dbSNP JSON files. The problem is caused by the dbSNP JSON files containing not an array of JSON objects. Instead, they contain one JSON object per line, also known as JSON lines [[5]]. Therefore, to get a list of all top-level keys without repetition, consider using the following (requires jq >=1.5)
```jq
[inputs] | add | keys
```

## How many assemmbly names?

For each record in the dbSNP JSON files, the demo parser script provided by the NCBI dbSNP repository [[2]] extracts the assembly name as the first element of `seq_id_traits_by_assembly` provided certain conditions. However, that element may contain more than one assembly name, e.g. in the MT sequence. The question then arises about how long the `seq_id_traits_by_assembly` arrays are.

To answer this question, consider the following script
```jq
def get_len:
  select(has("primary_snapshot_data")) 
  | .primary_snapshot_data.placements_with_allele
  | map(select(true == .is_ptlp))
  | map(.placement_annot.seq_id_traits_by_assembly)
  | map(length);
       
[ inputs | get_len[] ] | unique[]
```

The script starts by defining the function `get_len` which computes the length of the element `seq_id_traits_by_assembly` when certain conditions are met. Applying that function directly, as in `jq 'get_len`, would produce a sequence of results, but not an array of results. Wrapping it between square brackets or using `reduce` as indicated in [[3]] and [[4]] was of not help. Instead, I applied that function to `inputs`, and wrap it all in square brackets, which generated the array of results that can be passed to `unique`.


## References

[1]: https://github.com/stedolan/jq/wiki/Cookbook#list-keys-used-in-any-object-in-a-list
[2]: https://github.com/ncbi/dbsnp/blob/master/tutorials/rsjson_demo.py
[3]: https://stedolan.github.io/jq/manual/#TypesandValues
[4]: https://github.com/stedolan/jq/wiki/FAQ
[5]: https://programminghistorian.org/en/lessons/json-and-jq#json-vs-json-lines

1. https://github.com/stedolan/jq/wiki/Cookbook#list-keys-used-in-any-object-in-a-list
2. https://github.com/ncbi/dbsnp/blob/master/tutorials/rsjson_demo.py
3. https://stedolan.github.io/jq/manual/#TypesandValues
4. How can a stream of JSON entities be collected together in an array? https://github.com/stedolan/jq/wiki/FAQ
5. https://programminghistorian.org/en/lessons/json-and-jq#json-vs-json-lines
