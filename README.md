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


## Exporting tables in tsv format

Before reproducing the output of the demo parser script provided by the NCBI dbSNP repository [[2]], I would like to clarify how the final table is produced, and in particular, how the header is added. After much time spent in web search and experimentation, I arrived at a solution that I later found in [[6]] written by a user called [outis](https://stackoverflow.com/users/90527/outis). The solution is there explained with such exquisite level of detail and clarity, that I will not explain it here and instead kindly refer you there. 

In order to apply that solution to the dbSNP JSON files, we need to convert the JSON lines into an array of JSON objects as we did before. To that end, I employed the following
```jq
[ inputs | demo_filter ] | to_tsvh 
```
The script starts by wrapping the demo_filter output in an array and passing it to `to_tsvh`, which is defined as follows:
```jq
def to_tsvh:
  (.[0] | keys_unsorted) as $colnames
  | $colnames, map([.[$colnames[]]])[]
  | @tsv
;
```
This function creates the column names of the tsv file based on the keys of the first element in the results array. Contrary to the solution in [[7]], this solution makes sure that the exported values are in the same order as the column names.

Another solution was proposed there in [[6]], and also in [[8]], which can export tables in which some of the keys are missing in some of the results. This solution is more general than the one I chose, but it is unnecessary and less efficient for the case under consideration. 

## A demo parser for NCBI dbSNP

Under construction. The whole script can be found in [dbSNP_demo_parser.jq]

```jq
def get_ptlp:
  select(has("primary_snapshot_data")) 
  | .primary_snapshot_data.placements_with_allele
  | map(select(true == .is_ptlp))
;

def get_asm_name:
  map(.placement_annot.seq_id_traits_by_assembly[].assembly_name)
;

def get_alleles:
  map(.alleles[].allele.spdi)
  | map(select(.inserted_sequence!=.deleted_sequence))
;

def demo_filter:
  .refsnp_id as $rs
  | get_ptlp
  | { rsid: $rs, alleles: get_alleles[], asm_name: get_asm_name[] }    
  | . + .alleles
  | del(.alleles)
;
```

## References

[1]: https://github.com/stedolan/jq/wiki/Cookbook#list-keys-used-in-any-object-in-a-list
[2]: https://github.com/ncbi/dbsnp/blob/master/tutorials/rsjson_demo.py
[3]: https://stedolan.github.io/jq/manual/#TypesandValues
[4]: https://github.com/stedolan/jq/wiki/FAQ
[5]: https://programminghistorian.org/en/lessons/json-and-jq#json-vs-json-lines
[6]: https://stackoverflow.com/questions/32960857/how-to-convert-arbitrary-simple-json-to-csv-using-jq
[7]: https://stackoverflow.com/questions/30015555/how-to-add-a-header-to-csv-export-in-jq
[8]: https://www.freecodecamp.org/news/how-to-transform-json-to-csv-using-jq-in-the-command-line-4fa7939558bf/

1. https://github.com/stedolan/jq/wiki/Cookbook#list-keys-used-in-any-object-in-a-list
2. https://github.com/ncbi/dbsnp/blob/master/tutorials/rsjson_demo.py
3. https://stedolan.github.io/jq/manual/#TypesandValues
4. How can a stream of JSON entities be collected together in an array? https://github.com/stedolan/jq/wiki/FAQ
5. https://programminghistorian.org/en/lessons/json-and-jq#json-vs-json-lines
6. https://stackoverflow.com/questions/32960857/how-to-convert-arbitrary-simple-json-to-csv-using-jq
7. https://stackoverflow.com/questions/30015555/how-to-add-a-header-to-csv-export-in-jq
8. https://www.freecodecamp.org/news/how-to-transform-json-to-csv-using-jq-in-the-command-line-4fa7939558bf/
