use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use Cwd;
use POSIX;
use Parallel::ForkManager;

sub matplot{

my ($ss_hr,$dps_hr) = @_;
my $mainPath = $ss_hr->{main_dir};# main path of dpgen folder
my $currentPath = $ss_hr->{script_dir};
my $debug = $ss_hr->{debug};
my $trainNo = $ss_hr->{trainNo};
my $working_dir = $dps_hr->{working_dir};#training folder

$ss_hr->{iter} =~ s/^\s+|\s+$//;#could be "initial dp train" or integer
my $iter;
if ($ss_hr->{iter} =~ /^-?\d+\.?\d*$/){
    $iter = "iter". sprintf("%03d",$ss_hr->{iter});
}
else{
    $iter = "initial";
}

#my $forkNo = $trainNo;# $trainNo;
#my $pm = Parallel::ForkManager->new("$forkNo");

#doing the following in script folder
for (1..$trainNo){
    #$pm->start and next;
    my $temp = sprintf("%02d",$_);
    chomp $temp;
    #chdir("$mainPath/dp_train/graph$temp/");
    #system("rm -rf *");
	#system("sbatch ../slurm_dp$temp.sh");
    `rm ./lcurve.out`;#remove old lcurve.out in current dir 
    `rm ./temp.*.out`;#remove old dp test output files in current dir 
    `rm ./tempmod.*.out`;#remove old dp test output files in current dir 
    `cp  $mainPath/dp_train/graph$temp/lcurve.out ./`;#for loss profiles
    `cp  $mainPath/dp_train/graph$temp/lcurve.out ../matplot_data/lcurve_$iter-graph$temp.out`;#for raw data
    #the following for check pred. and ref. data distributions for energy, force, and virial 
    system("source activate deepmd-cpu;dp test -m $mainPath/dp_train/graph$temp/graph$temp.pb -s $mainPath/matplot -d ./temp.out;conda deactivate");
# get atom number for normalizing energy
    `cp  ./temp.e.out ../matplot_data/Oritemp.e_$iter-graph$temp.out`;#for raw data
    `cp  ./temp.f.out ../matplot_data/temp.f_$iter-graph$temp.out`;#for raw data
    `cp  ./temp.v.out ../matplot_data/temp.v_$iter-graph$temp.out`;#for raw data

    `mv ./temp.e.out ./tempmod.e.out`;# for the following touch temp.e.out
    my @temp = `grep "#" ./tempmod.e.out|awk '{print \$2}'`;
    die "No energy listed in temp.e.out after dp test" unless(@temp);
    chomp @temp;
    my $energyNo = @temp;
    if($energyNo == 1){
        print "Currently, only one reference energy in temp.e.out after dp test",
        " python script doesn't work if the energy number is 1. No png file is plotted.\n";
        last;
    }
    my @npypath = map {$_ =~ s/:$//g; $_;} @temp;#remove ":"
    die "not npy dirs for matplot\n" unless(@npypath);
    #chomp @npypath;
    my @atomNo;
    for my $npath (@npypath){
        #$_ =~ s/:$//g;
        #print "path: $_\n";
        my @temp = `cat $npath/coord.raw`;#get how many frames in this raw
        chomp @temp;
        for my $nu (@temp){
            $nu  =~ s/^\s+|\s+$//;
            my @sp = split(/\s+/,$nu);
            chomp @sp;
            my $num = @sp/3;
            push @atomNo,$num;
        }
    }
    my @tempdata = `grep -v "#" ./tempmod.e.out`;
    chomp @tempdata;
    my @data = grep (($_!~m{^\s*$|^#}),@tempdata); # remove blank elements
    my $dataNo = @data;
    my $atomarrayNo = @atomNo;
    die "the data number and atom number array are not equal\n" if($dataNo != $atomarrayNo);
    `touch ./temp.e.out`;
    for my $dt (0..$#data){
        $data[$dt]  =~ s/^\s+|\s+$//;
        #print "\$data[\$dt]: $data[$dt]\n";
        my @temp = split(/\s+/,$data[$dt]);
        chomp @temp;
        #print "dt: $dt, $temp[0] $temp[1]\n";
        $temp[0] = $temp[0]/$atomNo[$dt];
        $temp[1] = $temp[1]/$atomNo[$dt];
        #chmop @temp;
        `echo "$temp[0] $temp[1]" >> ./temp.e.out`;
    }
    `cp  ./temp.e.out ../matplot_data/itemp.e_$iter-graph$temp.out`;#for raw data

# end of energy normalization    
    system ("python dp_plots.py");
    sleep(1);
 #   die;
    `mv ./dp_temp.png $mainPath/matplot/iter_$iter-graph$temp.png`;    
    #$pm-> finish;
}
#$pm->wait_all_children;

#housekeeping
`rm ./lcurve.out`;#remove old lcurve.out in current dir 
`rm ./temp.*.out`;#remove old dp test output files in current dir
`rm ./tempmod.*.out`;#remove old dp test output files in current dir

#/dp_train/graph01/lcurve.out;
#
#cp ../dp_train/graph01/lcurve.out
#`rm -f test0503*`;
#system("source activate deepmd-cpu;dp test -m /home/jsp/Perl4dpgen/dp_train/graph01/graph01.pb -s /home/jsp/Perl4dpgen/matplot -d test0503.out");
#`python plot_e.py`;
##dp test -m /home/jsp/Perl4dpgen/dp_train/graph01/graph01.pb -s /home/jsp/Perl4dpgen/all_npysoft  -d testnew.out
##
##dp test -m /home/jsp/Perl4dpgen/dp_train/graph01/graph01.pb -s /home/jsp/Perl4dpgen/matplot  -d testnew.out

}# end sub
1;