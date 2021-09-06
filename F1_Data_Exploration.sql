/*
F1 Data Exploration

Skills used: Joins, CTE's, Temp Tables, Sub-Queries, Window Functions, Aggregate Functions, Creating Views, Converting Data Types
*/

-- Total number of races from 1950-2021
SELECT 
	count(raceId)
FROM
	races;
    
-- Number of races at each circuit

SELECT circuits.name, circuits.country, count(races.raceId) AS NumberOfRaces
FROM races
JOIN circuits
ON races.circuitId = circuits.circuitId
GROUP BY circuits.name, circuits.country
ORDER BY NumberOfRaces DESC;
 
 
-- Creating a View to save time in writing complex queries 

CREATE VIEW RaceResults AS
(SELECT races.name, races.year, drivers.driverId, CONCAT(drivers.forename, ' ', drivers.surname) AS driver, 
 results.grid, results.points, results.position, results.rank
FROM results
INNER JOIN drivers
ON results.driverId = drivers.driverId
INNER JOIN races
ON results.raceId = races.raceId
ORDER BY races.year, races.name);

  
-- Total points won by each driver and respective final rank in each championship

SELECT year, driver, sum(convert(points, signed)) AS TotalPoints, 
RANK() OVER (PARTITION BY year ORDER BY sum(convert(points, signed)) DESC) AS ChampionshipRank
FROM raceresults
GROUP BY driver, year
ORDER BY year DESC;


-- Driver with the most number of wins till date

SELECT driver, count(position) AS Wins
FROM raceresults
WHERE position = 1
GROUP BY driver
ORDER BY Wins DESC;


-- Drivers and number of their championship wins
    

SELECT a.driver, count(a.ChampionshipRank) AS ChampionshipWins
FROM
(
	SELECT year, driver, sum(convert(points, signed)) AS TotalPoints, 
	RANK() OVER (PARTITION BY year ORDER BY sum(convert(points, signed)) DESC) AS ChampionshipRank
	FROM raceresults
	GROUP BY driver, year
	ORDER BY year DESC, TotalPoints DESC
) AS a
WHERE ChampionshipRank = 1
GROUP BY a.driver
ORDER BY ChampionshipWins DESC;
    


-- Wins in each circuit

SELECT a.circuit, a.location, a.country, a.driver, count(a.driver) AS TimesWon
FROM
(	SELECT races.year, races.name, circuits.name AS circuit , circuits.location, circuits.country, 
	 CONCAT(drivers.forename, ' ', drivers.surname) AS driver, results.points, results.position
	FROM results
	INNER JOIN drivers
	ON results.driverId = drivers.driverId
	INNER JOIN races
	ON results.raceId = races.raceId
	INNER JOIN circuits
	ON races.circuitId = circuits.circuitId
	WHERE results.position = 1
	ORDER BY races.year DESC, races.name
) AS a
GROUP BY a.circuit, a.driver, a.location, a.country
ORDER BY a.circuit, TimesWon DESC;


-- Probability of winning in a circuit (Using Sub-Query)

SELECT b.circuit, b.location, b.country, b.driver, b.TimesWon, c.TimesRaced, (b.TimesWon/c.TimesRaced)*100 AS PercentWon
FROM
	(SELECT a.circuit, a.location, a.country, a.driver, count(a.driver) AS TimesWon
	FROM
		(SELECT circuits.name AS circuit, circuits.location, circuits.country, 
		 CONCAT(drivers.forename, ' ', drivers.surname) AS driver, results.position
		FROM results
		INNER JOIN drivers
		ON results.driverId = drivers.driverId
		 JOIN races
		ON results.raceId = races.raceId
		INNER JOIN circuits
		ON races.circuitId = circuits.circuitId
		WHERE results.position = 1) AS a
	GROUP BY a.circuit, a.driver, a.location, a.country
	ORDER BY a.country, TimesWon DESC
    ) AS b
    INNER JOIN
		(SELECT circuits.name AS circuit , circuits.location, 
		 CONCAT(drivers.forename, ' ', drivers.surname) AS driver, count(drivers.driverId) AS TimesRaced
		FROM results
		INNER JOIN drivers
		ON results.driverId = drivers.driverId
		INNER JOIN races
		ON results.raceId = races.raceId
		INNER JOIN circuits
		ON races.circuitId = circuits.circuitId
		GROUP BY circuits.name, circuits.location, CONCAT(drivers.forename, ' ', drivers.surname)
        ) AS c ON b.circuit = c.circuit and b.driver = c.driver 
ORDER BY PercentWon DESC;
    

-- Probability of winning in a circuit (Using Temp Table)

DROP TEMPORARY TABLE IF EXISTS WinsAtEachCircuit;
CREATE TEMPORARY TABLE WinsAtEachCircuit
(circuit text, location text, country text, driver text, TimesWon int);

INSERT INTO WinsAtEachCircuit (circuit, location, country, driver, TimesWon)
SELECT a.circuit, a.location, a.country, a.driver, count(a.driver) AS TimesWon
	FROM
		(SELECT circuits.name AS circuit, circuits.location, circuits.country, 
		 CONCAT(drivers.forename, ' ', drivers.surname) AS driver, results.position
		FROM results
		INNER JOIN drivers
		ON results.driverId = drivers.driverId
		 JOIN races
		ON results.raceId = races.raceId
		INNER JOIN circuits
		ON races.circuitId = circuits.circuitId
		WHERE results.position = 1) AS a
	GROUP BY a.circuit, a.driver, a.location, a.country
	ORDER BY TimesWon DESC;


DROP TEMPORARY TABLE IF EXISTS DriversAtEachCircuit;
CREATE TEMPORARY TABLE DriversAtEachCircuit
(circuit text, location text, country text, driver text, TimesRaced int);
    
INSERT INTO DriversAtEachCircuit(circuit, location, country, driver, TimesRaced)
SELECT circuits.name AS circuit , circuits.location, circuits.country, 
CONCAT(drivers.forename, ' ', drivers.surname) AS driver, count(drivers.driverId) AS TimesRaced
FROM results
INNER JOIN drivers
ON results.driverId = drivers.driverId
INNER JOIN races
ON results.raceId = races.raceId
INNER JOIN circuits
ON races.circuitId = circuits.circuitId
GROUP BY circuits.name, circuits.location, circuits.country, CONCAT(drivers.forename, ' ', drivers.surname)
ORDER BY TimesRaced DESC;
    

SELECT a.circuit, a.location, a.country, a.driver, (b.TimesWon/a.TimesRaced)*100 AS PercentWon
FROM DriversAtEachCircuit a 
inner join WinsAtEachCircuit b 
on a.driver = b.driver and a.circuit = b.circuit
ORDER BY PercentWon DESC;


-- Fastest lap time in each circuit

SELECT a.name, a.circuit, a.location, min(a.fastestLapTime) AS FastestLapTimeEver
FROM
(SELECT races.year, races.name, circuits.name AS circuit , circuits.location, circuits.country, results.fastestLapTime
FROM results
INNER JOIN races
ON results.raceId = races.raceId
INNER JOIN circuits
ON races.circuitId = circuits.circuitId
WHERE results.fastestLapTime NOT LIKE '%N%'
ORDER BY races.year DESC, races.name) AS a
GROUP BY a.name, a.circuit, a.location
ORDER BY a.name, a.location;


-- Constructors Champioship

SELECT races.year, races.date, races.name, constructors.name, constructor_results.points
FROM races
INNER JOIN constructor_results
ON races.raceId = constructor_results.raceId
INNER JOIN constructors
ON constructor_results.constructorId = constructors.constructorId
ORDER BY races.date DESC, points DESC;


-- Team with most number of championship wins (Using CTE)

WITH ConstructorWins (year, name, points, position) AS
(
SELECT races.year AS year, constructors.name, sum(constructor_results.points) AS points, 
	RANK() OVER (PARTITION BY year ORDER BY sum(constructor_results.points) DESC)
FROM races
INNER JOIN constructor_results
ON races.raceId = constructor_results.raceId
INNER JOIN constructors
ON constructor_results.constructorId = constructors.constructorId
GROUP BY year, constructors.name
ORDER BY year DESC, points DESC
) SELECT name, count(position) AS Wins
FROM ConstructorWins
WHERE position = 1
GROUP BY name
ORDER BY Wins DESC;
