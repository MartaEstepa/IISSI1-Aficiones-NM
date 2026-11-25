SELECT * 
FROM users;

SELECT AVG(u.age) AS media 
FROM users u;

SELECT u.gender, AVG(u.age) AS media
FROM users u
GROUP BY u.gender;


WITH m as
	(
	SELECT AVG(u.age) AS media
	FROM users u
	)
SELECT * 
FROM users n
WHERE n.age > media;