#!/usr/bin/bash -l
#SBATCH -p short -c 2 --mem 2gb -N 1 -n 1

module load ncbi-table2asn
module load ncbi-asn_tools
BASE=Acremonium_sp._UM1754
SBT=../../lib/sbt/UM1754.sbt
table2asn -l paired-ends -V v -M n -c ef -i $BASE.fsa -o $BASE.sqn -Z \
	-t $SBT -euk -j "[organism=Acremonium sp.] [strain=UM1754] [gcode=1]"

asn2all -i $BASE.sqn -f d -v $BASE.aa -o $BASE.cds
