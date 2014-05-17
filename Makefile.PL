
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Classify data with Analogical Modeling",
  "AUTHOR" => "Theron Stanford <shixilun\@yahoo.com>, Nathan Glenn <garfieldnate\@gmail.com>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Algorithm-AM",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Algorithm::AM",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Class::Tiny" => 0,
    "Exporter::Easy" => 0,
    "Import::Into" => 0,
    "Log::Any" => 0,
    "Path::Tiny" => 0,
    "Text::Table" => 0,
    "XSLoader" => 0,
    "feature" => 0,
    "integer" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Find" => 0,
    "File::Temp" => 0,
    "FindBin" => 0,
    "Test::Deep" => 0,
    "Test::Exception" => 0,
    "Test::LongString" => 0,
    "Test::More" => "0.88",
    "Test::NoWarnings" => 0
  },
  "VERSION" => "3.02",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



