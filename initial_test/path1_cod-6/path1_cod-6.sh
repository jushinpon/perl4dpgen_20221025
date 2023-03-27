#!/bin/sh
#sed_anchor01
#SBATCH --output=path1_cod-6.sout
#SBATCH --job-name=scf_path1_cod-6
#SBATCH --nodes=1
#SBATCH --partition=C24M32
#SBATCH --ntasks-per-node=24


export LD_LIBRARY_PATH=/opt/mpich-3.4.2/lib:/opt/intel/mkl/lib/intel64:$LD_LIBRARY_PATH
export PATH=/opt/mpich-3.4.2/bin:$PATH
#sed_anchor02
mpiexec /opt/QEGCC_MPICH3.4.2/bin/pw.x -in path1_cod-6.in



#squeue       # qstat
#scancel  1   # Delete JOB NO. 1 
#scontrol show job 1  # Check job NO.1 detail



################################################## DEBUG
#yum install dos2unix  #######   install this when you got as follows error messages
#sbatch: error: Batch script contains DOS line breaks (\r\n)
#sbatch: error: instead of expected UNIX line breaks (\n).
#dos2unix filename 