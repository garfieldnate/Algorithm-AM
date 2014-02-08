requires "Carp" => "0";
requires "Data::Dumper" => "0";
requires "Exporter::Easy" => "0";
requires "IO::Handle" => "0";
requires "Log::Any" => "0";
requires "Log::Dispatch" => "0";
requires "Log::Dispatch::File" => "0";
requires "Path::Tiny" => "0";
requires "XSLoader" => "0";
requires "feature" => "0";
requires "integer" => "0";
requires "perl" => "5.014";
requires "strict" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "File::Find" => "0";
  requires "File::Slurp" => "0";
  requires "File::Temp" => "0";
  requires "FindBin" => "0";
  requires "Test::Exception" => "0";
  requires "Test::LongString" => "0";
  requires "Test::More" => "0.88";
  requires "Test::NoWarnings" => "0";
  requires "Test::Warn" => "0";
  requires "subs" => "0";
  requires "vars" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "6.30";
};

on 'develop' => sub {
  requires "Dist::Zilla" => "4.300039";
  requires "Dist::Zilla::Plugin::ArchiveRelease" => "0";
  requires "Dist::Zilla::Plugin::AutoPrereqs" => "0";
  requires "Dist::Zilla::Plugin::Bugtracker" => "0";
  requires "Dist::Zilla::Plugin::CPANFile" => "0";
  requires "Dist::Zilla::Plugin::CheckChangesHasContent" => "0";
  requires "Dist::Zilla::Plugin::CheckPrereqsIndexed" => "0";
  requires "Dist::Zilla::Plugin::Clean" => "0";
  requires "Dist::Zilla::Plugin::ConfirmRelease" => "0";
  requires "Dist::Zilla::Plugin::CopyFilesFromBuild" => "0";
  requires "Dist::Zilla::Plugin::ExecDir" => "0";
  requires "Dist::Zilla::Plugin::GatherDir" => "0";
  requires "Dist::Zilla::Plugin::GenerateFile" => "0";
  requires "Dist::Zilla::Plugin::Git::Commit" => "0";
  requires "Dist::Zilla::Plugin::Git::NextVersion" => "0";
  requires "Dist::Zilla::Plugin::Git::Push" => "0";
  requires "Dist::Zilla::Plugin::Git::Tag" => "0";
  requires "Dist::Zilla::Plugin::GithubMeta" => "0";
  requires "Dist::Zilla::Plugin::Homepage" => "0";
  requires "Dist::Zilla::Plugin::InstallGuide" => "0";
  requires "Dist::Zilla::Plugin::License" => "0";
  requires "Dist::Zilla::Plugin::MakeMaker" => "0";
  requires "Dist::Zilla::Plugin::Manifest" => "0";
  requires "Dist::Zilla::Plugin::ManifestSkip" => "0";
  requires "Dist::Zilla::Plugin::MetaConfig" => "0";
  requires "Dist::Zilla::Plugin::MetaData::BuiltWith" => "0";
  requires "Dist::Zilla::Plugin::MetaJSON" => "0";
  requires "Dist::Zilla::Plugin::MetaNoIndex" => "0";
  requires "Dist::Zilla::Plugin::MetaProvides::Package" => "0";
  requires "Dist::Zilla::Plugin::MetaResources" => "0";
  requires "Dist::Zilla::Plugin::MetaTests" => "0";
  requires "Dist::Zilla::Plugin::MetaYAML" => "0";
  requires "Dist::Zilla::Plugin::MinimumPerl" => "0";
  requires "Dist::Zilla::Plugin::MojibakeTests" => "0";
  requires "Dist::Zilla::Plugin::NextRelease" => "0";
  requires "Dist::Zilla::Plugin::OurPkgVersion" => "0";
  requires "Dist::Zilla::Plugin::PodCoverageTests" => "0";
  requires "Dist::Zilla::Plugin::PodSyntaxTests" => "0";
  requires "Dist::Zilla::Plugin::PodWeaver" => "0";
  requires "Dist::Zilla::Plugin::Prepender" => "0";
  requires "Dist::Zilla::Plugin::Prereqs::AuthorDeps" => "0";
  requires "Dist::Zilla::Plugin::PruneCruft" => "0";
  requires "Dist::Zilla::Plugin::ReadmeAnyFromPod" => "0";
  requires "Dist::Zilla::Plugin::ReadmeFromPod" => "0";
  requires "Dist::Zilla::Plugin::ReportPhase" => "0";
  requires "Dist::Zilla::Plugin::ReportVersions::Tiny" => "0";
  requires "Dist::Zilla::Plugin::Repository" => "0";
  requires "Dist::Zilla::Plugin::RunExtraTests" => "0";
  requires "Dist::Zilla::Plugin::ShareDir" => "0";
  requires "Dist::Zilla::Plugin::Signature" => "0";
  requires "Dist::Zilla::Plugin::Test::CPAN::Changes" => "0";
  requires "Dist::Zilla::Plugin::Test::CPAN::Meta::JSON" => "0";
  requires "Dist::Zilla::Plugin::Test::Compile" => "0";
  requires "Dist::Zilla::Plugin::Test::DistManifest" => "0";
  requires "Dist::Zilla::Plugin::Test::Kwalitee" => "0";
  requires "Dist::Zilla::Plugin::Test::MinimumVersion" => "0";
  requires "Dist::Zilla::Plugin::Test::Perl::Critic" => "0";
  requires "Dist::Zilla::Plugin::Test::Pod::LinkCheck" => "0";
  requires "Dist::Zilla::Plugin::Test::Portability" => "0";
  requires "Dist::Zilla::Plugin::Test::Synopsis" => "0";
  requires "Dist::Zilla::Plugin::Test::UnusedVars" => "0";
  requires "Dist::Zilla::Plugin::Test::Version" => "0";
  requires "Dist::Zilla::Plugin::TestRelease" => "0";
  requires "Dist::Zilla::Plugin::UploadToCPAN" => "0";
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::CPAN::Meta" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
  requires "version" => "0.9901";
};
