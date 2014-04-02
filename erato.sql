DROP TABLE IF EXISTS dates;
DROP TABLE IF EXISTS shows;
DROP TABLE IF EXISTS places;

CREATE TABLE places(
	place VARCHAR(100) PRIMARY KEY,
	baseurl VARCHAR(100) NOT NULL
);
CREATE TABLE shows(
	url VARCHAR(200) PRIMARY KEY,
	title VARCHAR(300) NOT NULL,
	place VARCHAR(80) REFERENCES places(place) NOT NULL,
	img VARCHAR(200),
	description VARCHAR(600)
);
CREATE TABLE dates(
	url VARCHAR(100) REFERENCES shows(url),
	showtime TIMESTAMP,
	PRIMARY KEY (url, showtime)
);

INSERT INTO places VALUES ('Filharmonia', 'filharmonia.krakow.pl');
INSERT INTO places VALUES ('Słowacki - Duża Scena', 'slowacki.krakow.pl');
INSERT INTO places VALUES ('Słowacki - Scena Kameralna', 'slowacki.krakow.pl');
INSERT INTO places VALUES ('Stary - Duża Scena', 'stary.pl');
INSERT INTO places VALUES ('Stary - Scena Miniatura', 'stary.pl');
INSERT INTO places VALUES ('Bagatela - Karmelicka', 'bagatela.pl');
INSERT INTO places VALUES ('Bagatela - Sarego', 'bagatela.pl');
INSERT INTO places VALUES ('Opera', 'opera.krakow.pl');
