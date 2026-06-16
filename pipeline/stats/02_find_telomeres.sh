#!/usr/bin/env bash
#SBATCH -p short -N 1 -n 4 --mem 24gb  --out logs/find_telomees.log

module load parallel

mkdir -p reports
ls genomes/*.sorted.fasta | parallel -j 4 python  scripts_Hiltunen/find_telomeres.py {} \> reports/{/.}.telomere_report.txt
