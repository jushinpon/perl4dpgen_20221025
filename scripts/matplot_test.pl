use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use Cwd;
use POSIX;
use Parallel::ForkManager;
my $mainPath = getcwd();
my $iter = 5;

`cp ./temp.e.out ./tempmod.e.out`;# for the following touch temp.e.out
my @temp = `grep "#" ./tempmod.e.out|awk '{print \$2}'`;
chomp @temp;
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
`rm ./temp1.e.out`;
`touch ./temp1.e.out`;
for my $dt (0..$#data){
    $data[$dt]  =~ s/^\s+|\s+$//;
    
    print "\$data[\$dt]: $data[$dt]\n";
    my @temp = split(/\s+/,$data[$dt]);
    chomp @temp;
    print "dt: $dt, $temp[0] $temp[1]\n";
    $temp[0] = $temp[0]/$atomNo[$dt];
    $temp[1] = $temp[1]/$atomNo[$dt];
    #chmop @temp;
    `echo "$temp[0] $temp[1]" >> ././temp1.e.out`;
}
#print @atomNo;
#for (1..1){
#    my $temp = sprintf("%02d",$_);
#    chomp $temp;
#    `rm ./lcurve.out`;#remove old lcurve.out in current dir 
#    `rm ./temp.*.out`;#remove old dp test output files in current dir 
#    `cp  $mainPath/dp_train/graph$temp/lcurve.out ./`;#for loss profiles
#    #the following for check pred. and ref. data distributions for energy, force, and virial 
#    system("source activate deepmd-cpu;dp test -m $mainPath/dp_train/graph$temp/graph$temp.pb -s $mainPath/matplot -d ./temp.out");
#    
#    #system ("python dp_plots.py");
#    sleep(1);
#    `mv ./dp_temp.png $mainPath/matplot/iter_$iter-graph$temp.png`;    
#    #$pm-> finish;
#}
#$pm->wait_all_children;

#housekeeping
#`rm ./lcurve.out`;#remove old lcurve.out in current dir 
#`rm ./temp.*.out`;#remove old dp test output files in current dir

#/dp_train/graph01/lcurve.out;
#
#cp ../dp_train/graph01/lcurve.out
#`rm -f test0503*`;
#system("source activate deepmd-cpu;dp test -m /home/jsp/Perl4dpgen/dp_train/graph01/graph01.pb -s /home/jsp/Perl4dpgen/matplot -d test0503.out");
#`python plot_e.py`;
##dp test -m /home/jsp/Perl4dpgen/dp_train/graph01/graph01.pb -s /home/jsp/Perl4dpgen/all_npysoft  -d testnew.out
##
##dp test -m /home/jsp/Perl4dpgen/dp_train/graph01/graph01.pb -s /home/jsp/Perl4dpgen/matplot  -d testnew.out

