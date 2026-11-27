USE hobbies_nm_db; -- use hobbies ¡MUY IMPORTANTE!

-- ########################################
--               FUNCIONES
-- ########################################

DELIMITER //
CREATE OR REPLACE FUNCTION f_get_hobby_id(p_hobby_name VARCHAR(128)) -- función, dado el nombre de un hobbie devuelve su id
RETURNS INT
READS SQL DATA
BEGIN
	DECLARE v_hobby_id INT; -- * (definición de v_hobby_id como entero)
	
	SELECT MIN(h.hobby_id) INTO v_hobby_id -- select escalar (devuelve un entero) lo metemos en una variable de enteros pq está definido así en *
	FROM hobbies h
	WHERE h.hobby_name = p_hobby_name;
	
	RETURN v_hobby_id;
END//

DELIMITER ;

-- --------------------------------PRUEBA ---------------------------------
-- probamos la función: (cine está en el catálogo con id 1, y Ajedrez no está, así que NULL)
SELECT f_get_hobby_id('Cine') AS cine, f_get_hobby_id('Ajedrez') AS ajedrez;


-- nº de personas con la afición 
DELIMITER //
CREATE OR REPLACE FUNCTION f_hobby_users(p_hobby_id INT)
RETURNS INT
READS SQL DATA
BEGIN 
	DECLARE v_users INT;
	
	SELECT COUNT(*) INTO v_users
	FROM users_hobbies uh
	WHERE uh.hobby_id = p_hobby_id;
	
	RETURN v_users;
END // 

-- nº personas por afición
DELIMITER ;
SELECT h.hobby_id, h.hobby_name, f_hobby_users(h.hobby_id) AS num_users
FROM hobbies h
ORDER BY num_users DESC, h.hobby_id;


-- ########################################
--           1º   PROCEDIMIENTO
-- ########################################

DELIMITER //

-- funcion añade afición a usuario. si nueva, se añade, si ya la tenía ERROR
CREATE OR REPLACE PROCEDURE p_add_hobby_to_user(
	IN p_user_id INT,
	IN p_hobby_name VARCHAR(128)
)
BEGIN
	DECLARE v_hobby_id INT;
	
	SET v_hobby_id = f_get_hobby_id(p_hobby_name);
	
	IF EXISTS (	
		SELECT *
		FROM users_hobbies uh
		WHERE uh.user_id = p_user_id
			AND uh.hobby_id = v_hobby_id
	) THEN 
		SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'RN03: El usuario ya tiene esa afición';
	END IF;
	
	-- añadimos al catálogo si nueva
	IF v_hobby_id IS NULL THEN
		INSERT INTO hobbies (hobby_name) VALUES (p_hobby_name);
		SET v_hobby_id = LAST_INSERT_ID();
	END IF;
	
	INSERT INTO users_hobbies (user_id, hobby_id) VALUES (p_user_id, v_hobby_id);
END //

DELIMITER ;

-- --------------------------------PRUEBA ---------------------------------
-- miramos tabla, ejecutamos función, volvemos a ejecutar tabla para ver MODIFICACIONES
SELECT uh.user_id, h.hobby_name
FROM users_hobbies uh
JOIN hobbies h ON h.hobby_id = uh.hobby_id
WHERE uh.user_id = 1
;

CALL p_add_hobby_to_user(1, 'Cine');

SELECT uh.user_id, h.hobby_name
FROM users_hobbies uh
JOIN hobbies h ON h.hobby_id = uh.hobby_id
WHERE uh.user_id = 1
;

-- nº aficiones al acabar la modificación
SELECT COUNT(*) AS hobbies_in_catalog
FROM hobbies h;

DELIMITER //


-- ########################################
--            1º   TRANSACCIÓN
-- ########################################

CREATE OR REPLACE PROCEDURE p_add_hobby_to_user_tx(
	IN p_user_id INT,
	IN p_hobby_name VARCHAR(128)
)
BEGIN 
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END ;
	
	START TRANSACTION;
		CALL p_add_hobby_to_user(p_user_id, p_hobby_name);
	COMMIT;
END //

DELIMITER ;

-- --------------------------------PRUEBA ---------------------------------
CALL p_add_hobby_to_user_tx(3, 'Ajedrez'); 

SELECT uh.user_id, h.hobby_name
FROM users_hobbies uh
JOIN hobbies h ON h.hobby_id = uh.hobby_id
WHERE uh.user_id = 3
;

DELIMITER //

-- ########################################
--           2º  PROCEDIMIENTO
-- ########################################
-- fusiona afición old por la nueva, ambas en el catálogo, la antigua se borra
CREATE OR REPLACE PROCEDURE p_merge_hobbies(
	IN p_old_hobby_id INT,
	IN p_new_hobby_id INT
)
BEGIN
	IF p_old_hobby_id = p_new_hobby_id THEN
		SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'RI02: No se puede fusionar una afición consigo misma';
	END IF;
	
	IF NOT EXISTS (SELECT * FROM hobbies h WHERE h.hobby_id = p_old_hobby_id)
		OR NOT EXISTS (SELECT * FROM hobbies h WHERE h.hobby_id = p_new_hobby_id) THEN
			SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'RI02: Las dos aficiones deben estar en el catálogo';
	END IF;
	
	-- usuarios con ambas, pierden la antigua
	DELETE FROM users_hobbies
	WHERE hobby_id = p_old_hobby_id
		AND user_id IN (
			SELECT uh.user_id
			FROM users_hobbies uh
			WHERE uh.hobby_id = p_new_hobby_id
		);
		
	-- pasan de la antigua a nueva
	UPDATE users_hobbies
	SET hobby_id = p_new_hobby_id
	WHERE hobby_id = p_old_hobby_id;
	
	-- la antigua se borra del catálogo
	DELETE FROM hobbies
	WHERE hobby_id = p_old_hobby_id;
END//

-- ########################################
--            2º   TRANSACCIÓN
-- ########################################

CREATE OR REPLACE PROCEDURE p_merge_hobbies_tx(
	IN p_old_hobby_id INT,
	IN p_new_hobby_id INT
)
BEGIN 
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END ;
	
	START TRANSACTION;
		CALL p_merge_hobbies(p_old_hobby_id,p_new_hobby_id);
	COMMIT;
END //

DELIMITER ;

-- --------------------------------PRUEBA ---------------------------------
-- probamos la función: fusionamos jugar fútbol(3) con deporte(2) 
CALL p_populate();

SELECT h.hobby_id, h.hobby_name, f_hobby_users(h.hobby_id) AS users
FROM hobbies h
ORDER BY users DESC, h.hobby_id
;

CALL p_merge_hobbies_tx(3,2);

SELECT h.hobby_id, h.hobby_name, f_hobby_users(h.hobby_id) AS users
FROM hobbies h
ORDER BY users DESC, h.hobby_id
;

SELECT uh.user_id
FROM users_hobbies uh
WHERE uh.hobby_id = 2
ORDER BY uh.user_hobby_id

-- se dejan los datos como estaban
-- CALL p_populated();