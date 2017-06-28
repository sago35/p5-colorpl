#!/usr/bin/perl
use strict;
use utf8;
use Encode qw(decode encode);
use Win32::Console;
use Data::Dumper;

my $console = Win32::Console->new(STD_OUTPUT_HANDLE);
my $attr = $console->Attr;
local $| = 1;

# 上位4bitでBG色、下位4bitでFG色を設定可能
my $ATTR = {
    GREEN   => (($attr & 0xF0) | 10), # bg = black, fg = green
    CYAN    => (($attr & 0xF0) | 11), # bg = black, fg = cyan
    RED     => (($attr & 0xF0) | 12), # bg = black, fg = red
    MAGENTA => (($attr & 0xF0) | 13), # bg = black, fg = yellow
    YELLOW  => (($attr & 0xF0) | 14), # bg = black, fg = magenta
};

# 文字コードのデフォルト値
my $charcode = {
    in  => "cp932",
    out => "cp932",
};


my @rules;
if (grep /^(-h|--help)$/, @ARGV) {
    &help;
    exit;
}


my @input;
while (my $arg = shift @ARGV) {
    if ($arg eq "-i") {
        $charcode->{in} = shift @ARGV;
    } elsif ($arg eq "-o") {
        $charcode->{out} = shift @ARGV;
    } else {
        push @input, decode("cp932", $arg);
    }
}

while (my $arg = shift @input) {
    my $color = shift @input;
    if (not defined $color) {
        &help;
        exit;
    } elsif (exists $ATTR->{$color}) {
        push @rules, {
            regex => qr/$arg/,
            color => $ATTR->{$color},
        };
    } else {
        push @rules, {
            regex => qr/$arg/,
            color => hex $color,
        };
    }
}



binmode(STDIN, ":encoding($charcode->{in})");
my $regex = sprintf "(%s)", join "|", map {$_->{regex}} @rules;
$regex = qr/$regex/;
while (my $line = <STDIN>) {
    chomp $line;

    foreach my $match ($line =~ /$regex/g) {
        my $s = index($line, $match, 0);
        printf "%s", encode($charcode->{out}, substr($line, 0, $s));
        my ($xattr) = grep {$match =~ /^$_->{regex}$/} @rules;
        $console->Attr($xattr->{color});
        printf "%s", encode($charcode->{out}, substr($line, $s, length($match)));
        $console->Attr($attr);
        $line = substr($line, $s + length($match));
    }
    printf "%s\n", encode($charcode->{out}, $line);
}


sub help {
    printf encode("cp932", <<HELP);
$0
    文字コードを変換しつつ、正規表現で色づけを行うスクリプト


usage : perl $0  [ -i 入力文字コード ]  [ -o 出力文字コード ] [ REGEX  COLOR  ]*


    入出力文字コードは、デフォルト値はcp932となっています
        cp932 shijtjis eucjp utf8

    REGEXは、色づけを行う正規表現
    COLORは、色の名前もしくは0xFFまでの16進数1byte分
HELP

    printf "        ";
    foreach my $key (keys %$ATTR) {
        $console->Attr($ATTR->{$key});
        printf "%s", $key;
        $console->Attr($attr);
        printf " ";
    }
    printf "\n";

    foreach my $bg (0 .. 15) {
        printf "        ";
        foreach my $fg (0 .. 15) {
            $console->Attr(($bg << 4) + $fg);
            printf "0x%02X", ($bg << 4) + $fg;
            $console->Attr($attr);
            printf " ";
        }
        printf "\n";
    }
}
