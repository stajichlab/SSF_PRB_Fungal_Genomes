# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a fungal genome assembly, annotation, and comparative genomics pipeline for 5 Ascomycota isolates from Antrim Shale. All samples are Illumina-only (no RNA-seq). The pipeline is implemented as modular SLURM shell scripts — there is no workflow manager (no Snakemake/Nextflow).

## Sample Data

`samples.csv` is the central sample manifest (comma-delimited, header on line 1). Columns:
```
ID, FileBase, SRARun, Species, Strain, TaxonID, LocusTag, BioProject, BioSample, BUSCO, Notes
```
- `ID` — used as the stem for all input/output filenames
- `TaxonID` — NCBI taxon ID used by FCS-GX contamination screening
- `BUSCO` — lineage database for BUSCO assessment (per-sample, e.g. `sordariomycetes_odb10`, `eurotiomycetes_odb10`)
- `Notes` — samples marked `Too Low` are skipped in assembly scripts

Illumina reads are expected at `input/illumina/${ID}_R1.fastq.gz` and `input/illumina/${ID}_R2.fastq.gz`.

## Running Pipeline Steps

All scripts are SLURM batch scripts submitted with `sbatch`. Scripts that process per-sample use SLURM array jobs:

```bash
# Submit as array job (N = 1-based row index in samples.csv, excluding header)
sbatch --array=1-5 pipeline/asm/01_AAFTF.sh

# Or run a single sample interactively by passing N as argument
bash pipeline/asm/01_AAFTF.sh 1
```

Scripts that process all samples at once (e.g. `02_clean_fcsgx.sh`) are submitted without array indexing:
```bash
sbatch pipeline/asm/02_clean_fcsgx.sh
```

Logs are written to `logs/`.

## Pipeline Stages (in order)

### Assembly (`pipeline/asm/`)
1. **`01_AAFTF.sh`** — Trim (fastp → bbduk), filter, assemble with SPAdes, FCS adaptor screen → `asm/AAFTF/${ID}.vecscreen.fasta`
2. **`02_clean_fcsgx.sh`** — NCBI FCS-GX contamination purge (requires 500GB RAM, loads database to `/dev/shm`) → `asm/AAFTF/${ID}.fcs_gx.fasta`
3. **`03_AAFTF_finish.sh`** — Remove duplicates, polish with POLCA, sort contigs, compute assembly stats → `asm/AAFTF/${ID}.sorted.fasta`

### Polish (`pipeline/polish/`) — for long-read data
- Medaka (GPU), Pilon, NextPolish

### Scaffold (`pipeline/scaffold/`)
- RagTag (reference-guided), quickmerge, Flye-based scaffolding

### Annotation (`pipeline/annotation/`)
1. `01_mask.sh` — RepeatModeler + RepeatMasker
2. `02_RNAseq_train.sh` — PASA / Augustus training (skipped for these samples; no RNA)
3. `03_predict.sh` — funannotate predict with Augustus + BUSCO seed species
4. `06_annotate_function.sh` — funannotate annotate (InterProScan, AntiSMASH)

### Stats / QC (`pipeline/stats/`)
- Assembly stats, BUSCO completeness, read mapping

### Comparative (`pipeline/comparative/`)
- OrthoFinder, domain analysis

## Key Environment Details

- **Cluster**: UCR HPCC (SLURM); modules loaded via `module load`
- **AAFTF_DB**: `/bigdata/stajichlab/shared/lib/AAFTF_DB`
- **FCS-GX DB**: `/srv/projects/db/ncbi-fcs/0.5.4/gxdb` (rsync'd to `/dev/shm` at runtime)
- AAFTF >= 0.3.1 required (for full fastp options)
- Working files for SPAdes go to `working_AAFTF/`; intermediate trimmed reads are cleaned up after assembly

## samples.csv Parsing Convention

All scripts must use this pattern (canonical form from `annotation/03_predict.sh`):

```bash
SAMPLEFILE=samples.csv
IFS=,
tail -n +2 $SAMPLEFILE | sed -n ${N}p | while read ID FILEBASE SRARUN SPECIES STRAIN TAXONID LOCUSTAG BIOPROJECT BIOSAMPLE BUSCO NOTES
```

Key rules:
- Variable name is `SAMPLEFILE` (not `SAMPLES` or `SAMPFILE`)
- Always use `tail -n +2` to skip the header before `sed -n ${N}p`
- All 11 columns must be named in the `read` statement; omitting `BUSCO` causes `NOTES` to receive the wrong value
- Scripts iterating all samples (no array) use `tail -n +2 $SAMPLEFILE | while read ...`

Scripts in `pipeline/polish/`, `pipeline/scaffold/`, and `pipeline/stats/04_read_count*.sh` have been updated to use the correct CSV reading, but their **internal logic** (file paths referencing `canu`, `flye`, `$NANOPORE`, `$ILLUMINA`) is carried over from a long-read workflow and needs updating before use with this Illumina-only project.

## Code Style

Defined in `.editorconfig` (repo root):
- Shell scripts (`.sh`): 4-space indent
- CSV/YAML/JSON: 2-space indent
- UTF-8, LF line endings, final newline required
