#! /usr/bin/env bash

dir1=$( pwd )
dir_in='/glade/p/univ/ufsu0011/SPECTRE/MITgcm'
root_mem='000'

for iii in {001...047}; do
  cp -r ${dir_in}/memb${root_memm}/ ${dir_in}/memb${iii}
  cd ${dir_in}/memb${iii}
  sed -i s/mem_nb=${root_mem}/mem_nb=${iii} pc.vars
  cd ${dir1}
done
