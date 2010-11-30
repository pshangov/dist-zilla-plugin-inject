package Dist::Zilla::Plugin::Inject;

use Class::Load qw(load_class);
use Try::Tiny qw(try catch);
use CPAN::Mini::Inject;
use CPAN::Mini::Inject::Remote;
use Moose;
use Moose::Util::TypeConstraints;
use File::Temp qw();

with 'Dist::Zilla::Role::Releaser';

has 'remote_server' => (
	is        => 'ro',
	isa       => 'Str',
	predicate => 'is_remote',
);

has 'config_file' => (
	is        => 'ro',
	isa       => 'Str',
	predicate => 'has_config_file',
);

has 'author_id' => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

has 'module' => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $name = $_[0]->zilla->name;
		$name =~ tr/\-/::/;
		return $name;
	},
);

has 'injector' => (
	is      => 'ro',
	isa     => subtype( 'Object' => where { $_->isa('CPAN::Mini::Inject') or $_->isa('CPAN::Mini::Inject::Remote') } ),
	lazy    => 1,
	default => sub 
	{
		my $self = shift;
		my $i;
		if ($self->is_remote)
		{
			load_class('CPAN::Mini::Inject::Remote');
			$i = CPAN::Mini::Inject::Remote->new( remote_server => $self->remote_server );
		}
		else
		{
			load_class('CPAN::Mini::Inject');
			$i = CPAN::Mini::Inject->new;
			$i->parsecfg($self->config_file);
		}
		return $i;
	},
);

sub release {
	my ($self, $archive) = @_;

	my $i = $self->injector;
	
	my %add_options;

	if ($self->is_remote)
	{
		# CPAN::Mini::Inject::Remote API
		%add_options = (
			module_name => $self->module, 
			author_id   => $self->author_id, 
			version     => $self->zilla->version, 
			file_name   => $archive->stringify,
		);
	}
	else
	{
		# CPAN::Mini::Inject API
		%add_options = (
			module   => $self->module, 
			authorid => $self->author_id, 
			version  => $self->zilla->version, 
			file     => $archive->stringify,
		);
	}

	try 
	{
		$i->add(%add_options);
		$i->inject;
	} 
	catch 
	{
		chomp;
		$self->log_fatal($_);
	};
}


1;
