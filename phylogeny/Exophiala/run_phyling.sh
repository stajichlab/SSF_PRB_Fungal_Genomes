#!/bin/bash -l
#SBATCH -p epyc
#SBATCH -c 2
#SBATCH --mem 8G
#SBATCH --time 7-00:00:00
#SBATCH --job-name nf_phyling
#SBATCH --output logs/nf_phyling_%j.log

# Nextflow orchestration ("head") job for the nf_phyling phylogenomics pipeline.
# This process is lightweight — it only submits and monitors the real SLURM
# child jobs (phyling align/filter/tree, phykit, modeltest-ng, iqtree3, raxml-ng).
#
# Run:   sbatch run_phyling.sh
#
# Workflow: PHYLING align/filter (top 50 markers) -> PhyKIT concat ->
#           ModelTest-NG (AIC + BIC) -> IQ-TREE 3 (UFBoot+SH-aLRT) AND
#           RAxML-NG (ML + bootstraps), for markerset ascomycota_odb12.

set -euo pipefail

mkdir -p logs
module load nextflow

INPUT=$(realpath input)
PREFIX=Exophiala_v1
MARKERSET=ascomycota_odb12
OUTDIR=results/${PREFIX}_protein

mkdir $PREFIX

nextflow run stajichlab/nf_phyling \
    -profile slurm,ucr_hpcc \
    -c phyling_modules.config \
    -resume \
    --seq_type protein \
    --input "${INPUT}" \
    --prefix "${PREFIX}" \
    --markerset "${MARKERSET}" \
    --top_n_to_keep 50 \
    --bs_count 1000 \
    --alrt_count 1000 \
    --bs_trees_pep 100 \
    --publish_mode copy \
    --outdir "${OUTDIR}" \
    "$@"
