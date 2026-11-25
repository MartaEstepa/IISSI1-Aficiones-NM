DROP DATABASE IF EXISTS transactions_db;
CREATE DATABASE transactions_db;
USE transactions_db;

CREATE OR REPLACE TABLE accounts (
	account_id INT NOT NULL AUTO_INCREMENT,
	holder VARCHAR(32) NOT NULL,
	balance DECIMAL(9,2) NOT NULL,
	PRIMARY KEY (account_id),
	CONSTRAINT ck_accounts_rn01_balance CHECK (balance >= 0)
);

CREATE OR REPLACE TABLE movements (
	movement_id INT NOT NULL AUTO_INCREMENT,
	account_id INT NOT NULL,
	date_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	amount DECIMAL(9,2) NOT NULL,
	debit_credit ENUM('D', 'H') NOT NULL,
	concept VARCHAR(32) NOT NULL,
	PRIMARY KEY (movement_id),
	FOREIGN KEY (account_id) REFERENCES accounts (account_id),
	CONSTRAINT ck_movements_rn02_amount CHECK (amount > 0)
);

-- RN03: un movimiento al haber ('H') aumenta el saldo
-- de su cuenta y uno al debe ('D') lo reduce
DELIMITER //
CREATE OR REPLACE TRIGGER t_ai_movements_rn03_balance
AFTER INSERT ON movements
FOR EACH ROW
BEGIN
	IF NEW.debit_credit = 'H' THEN
		UPDATE accounts SET balance = balance + NEW.amount
			WHERE account_id = NEW.account_id;
	ELSE
		UPDATE accounts SET balance = balance - NEW.amount
			WHERE account_id = NEW.account_id;
	END IF;
END //
DELIMITER ;

-- Abre una cuenta con su movimiento de apertura en una transacción: o entran
-- la cuenta y el movimiento, o no entra ninguno
DELIMITER //
CREATE OR REPLACE PROCEDURE p_open_account(
	p_holder VARCHAR(32),
	p_debit_credit CHAR(1),
	p_amount DECIMAL(9,2))
BEGIN
	START TRANSACTION;

	tblock: BEGIN
		-- Ante cualquier error o aviso se deshace la transacción y se relanza
		-- el error (RESIGNAL) para que lo reciba quien llamó al procedimiento
		DECLARE EXIT HANDLER FOR SQLEXCEPTION, SQLWARNING
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;

		INSERT INTO accounts (holder, balance) VALUES (p_holder, 0);
		INSERT INTO movements (account_id, amount, debit_credit, concept)
			VALUES (LAST_INSERT_ID(), p_amount, p_debit_credit, 'Apertura de cuenta');

		COMMIT;
	END tblock;
END //
DELIMITER ;