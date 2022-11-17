#!/bin/sh
#sed_anchor01
#SBATCH --output=dp01.out
#SBATCH --job-name=dp01
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --partition=debug
##SBATCH --exclude=node18,node20
export LD_LIBRARY_PATH=/opt/mpich-3.4.2/lib:$LD_LIBRARY_PATH
export PATH=/opt/mpich-3.4.2/bin:$PATH
export LD_LIBRARY_PATH=/opt/intel/compilers_and_libraries_2018.0.128/linux/mkl/lib/intel64_lin:$LD_LIBRARY_PATH
#export PATH=/opt/mpich-3.4.2/bin:$PATH

#adjsut ram consumption
memory=`free -m|grep Mem|awk '{print $NF}'`
memory=`printf %.0f $(echo "$memory * 0.98" |bc)`
SLURM_MEM_PER_NODE=$memory
export SLURM_MEM_PER_NODE

#mpiexec_anchor
mpiexec /opt/QEGCC_MPICH3.4.2/bin/pw.x -in dft_script.in
echo "Done" > dft_done.txt
