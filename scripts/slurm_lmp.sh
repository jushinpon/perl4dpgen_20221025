#!/bin/sh
#sed_anchor01
#SBATCH --output=dp01.out
#SBATCH --job-name=dp01
##SBATCH --nodes=1
##SBATCH --ntasks-per-node=8
#SBATCH --partition=debug
##SBATCH --reservation=GPU_test
##SBATCH --exclude=node18,node20
threads=`lscpu|grep "^CPU(s):" | sed 's/^CPU(s): *//g'`
export OMP_NUM_THREADS=$threads
export LD_LIBRARY_PATH=/opt/mpich-3.4.2/lib:$LD_LIBRARY_PATH
export PATH=/opt/mpich-3.4.2/bin:$PATH
source activate deepmd-cpu
#mpiexec_anchor
#lmp -in lmp_script.in
#mpi could make the node shutdown, but sed in lmp_label.pl will amend it.
echo "Done" > lmp_done.txt
