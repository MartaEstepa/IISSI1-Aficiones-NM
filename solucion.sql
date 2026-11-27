USE hobbies_nm_db; -- use hobbies ¡MUY IMPORTANTE!

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

-- probamos la función:
SELECT f_get_hobby_id('Cine') AS cine, f_get_hobby_id('Ajedrez') AS ajedrez;


DELIMITER //
-- CREATE OR REPLACE FUNCTION f_hobby_users(p_hobby_id INT)