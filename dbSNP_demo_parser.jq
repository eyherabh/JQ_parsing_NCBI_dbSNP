# jq definitions for converting dbSNP jsons into tables analogous to those from the NCBI dbSNP demo parser.
#
# Copyright (c) 2020 Ph.D. Hugo Gabriel Eyherabide
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
