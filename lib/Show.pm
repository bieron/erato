package Show;
use Moose;
use utf8;
binmode STDOUT, ':utf8';


has 'title' => (is => 'ro', isa => 'Str', required=>1);
has 'author' => (is => 'ro', isa => 'Str');
has 'director' => (is => 'ro', isa => 'Str');
has 'place' => (is => 'ro', isa => 'Str');
has 'url' => (is => 'ro', isa => 'Str');
has 'desc' => (is => 'ro', isa => 'Str');
has 'dates' => (is => 'rw', isa => 'ArrayRef');

=begin
sub dow {#class helper
   my$dow = lc substr(shift,0,3);
   $dow = 'wt' if $dow eq 'wto';
   $dow = 'pt' if $dow =~ /pi./;
   $dow = 'nd' if $dow eq 'nie';
}
=cut
around BUILDARGS => sub {
#   my($orig,$class) = (shift,shift);#hopefully executes in always the same order, not like C
   my$orig = shift;
   my$class = shift;
   my%args;
   if(@_ == 1 && ref $_[0]) {
      %args = %{ $_[0] };
   } else {
      %args = @_;
   }
   for (keys %args) {
      $args{$_} =~ s/^\s+//g;
      $args{$_} =~ s/\s+$//g;
      $args{$_} =~ s@<br[^>]+>@\n@g;
      $args{$_} =~ s/[ \t^\n]+/ /g;
      $args{$_} =~ s/<[^>]+>//g;
   }
   #$args{title} = ucfirst lc $args{title};
   $class->$orig(%args);
};

sub toStr {
   my$self = shift;
   print $self->title;
   print $self->url;
   print substr($self->desc,0,10);
   print join ', ', @$_ for (@{$self->dates});
}

sub toHTML {
   my$self = shift;
   my$s = '<td><a href="'.$self->url.'">'.$self->title.'</a><br/>';
   my@tmp = @{ $self->dates };
   $s .= join '<br/>', map {join ', ', @$_} @tmp;
   $s .= '</td>';
   return $s;
}

__PACKAGE__->meta->make_immutable;
1;
