drop table if exists dates;
drop table if exists shows;
drop table if exists places;

create table places(
	place varchar(100) primary key,
	baseurl varchar(100) not null
);
create table shows(
	url varchar(200) primary key,
	title varchar(500) not null,
	place varchar(100) references places(place)
);
create table dates(
	url varchar(100) references shows(url),
	showtime timestamp not null
);

insert into places values ('Filharmonia', 'filharmonia.krakow.pl');
insert into places values ('Słowacki - Duża Scena', 'slowacki.krakow.pl');
insert into places values ('Słowacki - Scena Kameralna', 'slowacki.krakow.pl');
insert into places values ('Stary - Duża Scena', 'stary.pl');
insert into places values ('Stary - Scena Miniatura', 'stary.pl');
insert into places values ('Bagatela', 'bagatela.pl');
