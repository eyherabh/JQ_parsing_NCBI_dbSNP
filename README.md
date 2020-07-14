# Using JQ by parsing NCBI dbSNP

Questions and answers about 

+ the application of JQ to parse NCBI dbSNP, 
+ the structure and content of NCBI dbSNP json files, and 
+ the correctness of the demo parsers provided by the NCBI repository.

## Listing all top-level keys

The advice given by [[1]] works for arrays of JSON objects. However, it does not work for the dbSNP JSON files. Running 
```jq
< refsnp-chrMT.json jq 'add | keys'
```
produces a sequence of errors like the following
```
jq: error (at <stdin>:1): string ("89362000-0...) and array ([]) cannot be added
```

The problem is caused by the dbSNP JSON files containing not an array of JSON objects, but one JSON object per line, also known as JSON lines [[5]]. Therefore, to get a list of all top-level keys without repetition, consider using the following (requires jq >=1.5)
```bash
< refsnp-chrMT.json jq -n '[ inputs ] | add | keys'
```

The `-n` flag is important: without it, the first json line would be ignored in the result.

## How many assemmbly names?

For each record in the dbSNP JSON files, the demo parser script provided by the NCBI dbSNP repository [[2]] extracts the assembly name as the first element of `seq_id_traits_by_assembly` provided certain conditions. However, that element may contain more than one assembly name, e.g. in the MT sequence. The question then arises about how long the `seq_id_traits_by_assembly` arrays are.

To answer this question, consider creating a module called `libdbsnp.jq` with the following function
```jq
def get_num_asm(cond):
  select(has("primary_snapshot_data")) 
  | .primary_snapshot_data.placements_with_allele
  | map(select(cond))
  | map(.placement_annot.seq_id_traits_by_assembly)
  | map(length);
```
The function `get_num_asm` computes the number of assembly names (i.e. the length of the element `seq_id_traits_by_assembly`) for each entry satisfying the condition `cond`. In this case, the condition only preserves the entries for which `is_ptlp` is `true`. Applying that function directly, namely
```bash
jq 'include "libdbsnp"; get_num_asm'
```
would produce a sequence of results, but not an array of results. Wrapping it between square brackets or using `reduce` as indicated in [[3]] and [[4]] was of not help. Instead, execute the following command
```bash
jq -n 'include "libdbsnp"; [ inputs | get_num_asm(true == .is_ptlp) ] | unique'
```
which generated the array of results that can be passed to `unique`. As before, the script should be run with the flag `-n` activated.



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

## A jq demo parser for NCBI dbSNP

The demo parser the the dbSNP JSONs provided in [[2]] only extracts information when `is_ptlp` is true, and is only correct when `seq_id_traits_by_assembly` is a singleton. Instead, I will build a demo parser that takes into account both the possibility that `seq_id_traits_by_assembly` by empty or have multiple values, and all positions regardless of which ones are preferred. 

To that end, consider the functions defined [here](dbSNP_demo_parser.jq) reproduced below

```jq
def get_asm_name:
  .placement_annot.seq_id_traits_by_assembly[].assembly_name // null 
;

def get_alleles:
  .alleles[].allele.spdi | select(.inserted_sequence!=.deleted_sequence)
;

def demo_filter:
  .refsnp_id as $rs
  | select(has("primary_snapshot_data")) 
  | .primary_snapshot_data.placements_with_allele[]
  | { rsid: $rs, is_ptlp, alleles:  get_alleles , asm_name: get_asm_name }
  | . + .alleles
  | del(.alleles)
;

def to_tsvh:
  (.[0] | keys_unsorted) as $colnames
  | $colnames, map([.[$colnames[]]])[]
  | @tsv
;
```
Equiped with these functions, one can extract, for example, all the positions for the assembly GRCh38.p12 by running
```bash
jq -n -r 'include "dbSNP_demo_parser";
[ inputs | demo_filter | select(.asm_name=="GRCh38.p12") ] | to_tsvh'
```

### Explanation

The command starts by invoking `jq` with the `-n` and `-r` flags. The reason for the `-n` flag was explained before. The `-r` flag is used for producing the results as raw strings, e.g. `A	B` instead of `"A\tB"`. 

The jq script (i.e. the part between single quotes) starts by piping the JSON lines into the `demo_filter` function. This function builds one or many objects depending on the output produced by the functions `get_alleles` and `get_asm_name`. These two functions operate on arrays (as per the dbSNP JSON schema) and return a list of objects (as opposed to an array). If both lists contain a single object, then `demo_filter` produces a single object. However, if any of them contains multiple objects, say `N` and `M`, then `demo_filter` will procude `NxM` objects (`x` denoting multiplication), built from the Cartesian product of the lists. 

For example, consider the commands
```
jq -n 'def a: 1,2; def b: 3,4; {  "a": a, "b": b}' 
jq -n 'def a: [1,2]; def b: [3,4]; {  "a": a, "b": b}' 
```
The first command produces
```
{
  "a": 1,
  "b": 3
}
{
  "a": 1,
  "b": 4
}
{
  "a": 2,
  "b": 3
}
{
  "a": 2,
  "b": 4
}
```
whereas the last command produces
```
{
  "a": [
    1,
    2
  ],
  "b": [
    3,
    4
  ]
}
```

However, the array onto which `get_asm_name` operates may be empty, in which case no object would be produce. Because I would rather have an object with the asm_name empty, I wrote `get_asm_name` so that it produces `null` in that case, thereby preserving positions and alleles in the cases where `asm_name` is empty.

Those and other cases can be later removed by filtering through the `select` statement. To allow for more flexibility, I wrote the bash script [jq_dbSNP_parser.sh] which allows for arbitrary selections.

## Downloading and parsing in parallel

To download and parse the NCBI dbSNP JSON files concurrently, consider the following command
```
rsfile="refsnp-chrMT.json.bz2"  
curl -s "ftp://ftp.ncbi.nih.gov/snp/latest_release/JSON/$rsfile" \
  | tee >(md5sum > "md5sum.$rsfile") \
  | bzip2 -dcq \
  | jq ... \
```
where `...` should be replaced by suitable values for the jq invocation. This script computes the md5sum for later comparison with the one in the NCBI dbSNP repository.

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
