---- Connecting sys as sysdba
connect sys/sys as sysdba;

-- Dropping the user from script Clearwater
DROP USER des02 CASCADE;

-- Running the script Clearwater
@C:\BD1\7clearwater.sql

SPOOL C:\BD2\project_part8_spool.txt
SELECT to_char(sysdate,'DD Month YYYY Day HH:MI"SS') FROM dual;

SET SERVEROUTPUT ON

CREATE OR REPLACE PACKAGE order_package IS
	global_inv_id NUMBER;
	global_quantity NUMBER;
	verify BOOLEAN;

	-- starting the declaration of functions and procedures

	FUNCTION verify_quantity (p_inv_qoh NUMBER) RETURN BOOLEAN;
	PROCEDURE update_qoh (p_inv_id NUMBER);
	PROCEDURE create_new_order (p_customer_id NUMBER, p_meth_pmt VARCHAR2, p_os_id NUMBER);
	PROCEDURE create_new_order_line(p_order_id NUMBER);

END;
/

	-- Sequence created to manage the order_line
CREATE SEQUENCE order_sequence START WITH 7;

	-- Package body initialization
CREATE OR REPLACE PACKAGE BODY order_package AS

	-- Procedure to create a new order
PROCEDURE create_new_order (p_customer_id NUMBER, p_meth_pmt VARCHAR2, p_os_id NUMBER) AS
	v_order_id NUMBER;

	BEGIN

			-- SELECT command to insert into order_id a new value using the sequence declared
		SELECT order_sequence.NEXTVAL
		INTO v_order_id
		FROM dual;

			-- INSERT used to insert the new order_id using the date of the system, the payment method
			-- inserted by the user, the customer id informed and the os id informed    
		INSERT INTO orders
		VALUES(v_order_id,sysdate,p_meth_pmt,p_customer_id,p_os_id);

			-- Calling the function to verify se the quantity is valid
            verify := VERIFY_QUANTITY(global_quantity);

			-- When the quantity is valid, then it calls the procedure create_new_order_line
			-- then it calls the procedure update_qoh that does what the name says and commits
            IF (verify = TRUE) THEN        
			CREATE_NEW_ORDER_LINE(v_order_id);
			UPDATE_QOH(global_inv_id);
    			COMMIT;

			-- When the quantiti is invalid, then it shows to the user that the quantity is invalid
            ELSIF (verify = FALSE) THEN
                DBMS_OUTPUT.PUT_LINE('Quantity not supported.');
            END IF;
            
	END create_new_order;

	-- Procedure to create a new order    
PROCEDURE create_new_order_line(p_order_id NUMBER) AS
			
	BEGIN

		-- It inserts into order line a new row with order_id, the global inv_id and the global
		-- quantity
		INSERT INTO order_line
		VALUES(p_order_id,global_inv_id, global_quantity);
		COMMIT;

	END create_new_order_line;
            
	-- Procedure to update the quantity on hand
PROCEDURE update_qoh (p_inv_id NUMBER) AS
            
	BEGIN

			-- here it updates the inventory removing the global quantity informed
            UPDATE inventory
            SET inv_qoh = inv_qoh - global_quantity
            WHERE inv_id = p_inv_id;
            
	END update_qoh;
        
	-- Function to verify the quantity on hand
FUNCTION verify_quantity (p_inv_qoh IN NUMBER)
	RETURN BOOLEAN IS
	approved BOOLEAN;
	v_inv_qoh NUMBER;

	BEGIN
			-- It selects the quantity on hand of the inventory where the global inventory id is the same
			-- as the inventory id
		SELECT inv_qoh
            INTO v_inv_qoh
            FROM inventory
            WHERE inv_id = global_inv_id;

			-- If the quantity on hand from the inventory is bigger than the quantity on hand informed,
			-- then it approves the procedure
		IF (v_inv_qoh > p_inv_qoh) THEN
            	DBMS_OUTPUT.PUT_LINE('Quantity approved.');
            	approved := TRUE;
 
			-- If the quantity on hand from the inventory is smaller than the quantity on hand informed,
			-- then it do not approves the procedure       		
		ELSIF (v_inv_qoh < p_inv_qoh) THEN
            	DBMS_OUTPUT.PUT_LINE('Quantity ' || p_inv_qoh || ' is bigger than the quantity on hand ' || v_inv_qoh || ' for the product ' || global_inv_id || '.');
            	approved := FALSE;
            	
		END IF;

        	RETURN approved;

	END verify_quantity;

END order_package;

/

SET SERVEROUTPUT ON

-- Test for inventory id = 32 and the quantity of 90;
BEGIN
	order_package.global_inv_id := 32;
	order_package.global_quantity := 90;
END;
/

-- Executing the procedure create_new_order
BEGIN
	order_package.create_new_order(1,'CASH',4);
END;
/

-- Checking the result
SELECT inv_id, inv_qoh FROM inventory;

-- Executing the same procedure again and checking the result
BEGIN
	order_package.create_new_order(1,'CASH',4);
END;
/
SELECT inv_id, inv_qoh FROM inventory;


-- Test for inventory id = 23 and the quantity of 90
BEGIN
	order_package.global_inv_id := 25;
	order_package.global_quantity := 90;
END;
/
-- Executing the same procedure again and checking the result
BEGIN
	order_package.create_new_order(1,'CASH',4);
END;
/
SELECT inv_id, inv_qoh FROM inventory;


-- QUESTION 2

connect sys/sys as sysdba;

DROP USER des04 CASCADE;
 
@C:\BD1\7Software.sql

SET SERVEROUTPUT ON

CREATE OR REPLACE PACKAGE consultants_general IS
	global_c_id NUMBER;
	global_skill_id NUMBER;

	FUNCTION check_certification (in_certification VARCHAR2) RETURN BOOLEAN;
	FUNCTION check_skill_id (in_skill_id NUMBER) RETURN BOOLEAN;
	FUNCTION check_combination (in_c_id NUMBER, in_skill_id NUMBER) RETURN BOOLEAN;
	FUNCTION certified (in_c_id NUMBER, in_skill_id NUMBER, in_certification VARCHAR2) RETURN VARCHAR2;

	PROCEDURE update_certification (in_c_id NUMBER, in_skill_id NUMBER, in_certification VARCHAR2);
	PROCEDURE insert_certification (in_c_id NUMBER, in_skill_id NUMBER, in_certification VARCHAR2);
	PROCEDURE print (in_c_id NUMBER, in_skill_id NUMBER);
	PROCEDURE update_insert (in_c_id NUMBER, in_skill_id NUMBER, in_certification VARCHAR2);
END;
/

CREATE OR REPLACE PACKAGE BODY consultants_general IS

FUNCTION check_certification (in_certification VARCHAR2)
    RETURN BOOLEAN IS
    checked_certification BOOLEAN;
    
    BEGIN

        IF (in_certification <> 'Y' AND in_certification <> 'N') THEN
            DBMS_OUTPUT.PUT_LINE('Certification ' || in_certification || ' is invalid.');
            DBMS_OUTPUT.PUT_LINE('Use Y or N uppercase as input for certification.');
            checked_certification := FALSE;
        ELSE
            checked_certification := TRUE;
        END IF;
	
	RETURN checked_certification;

    END check_certification;


FUNCTION check_skill_id (in_skill_id NUMBER)
	RETURN BOOLEAN IS
	checked_skill_id BOOLEAN;
	v_skill_id NUMBER;

    	BEGIN

		SELECT skill_id
		INTO v_skill_id
		FROM skill
		WHERE skill_id = in_skill_id;

		checked_skill_id := TRUE;

		RETURN checked_skill_id;

		EXCEPTION
			WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('Skill ID ' || in_skill_id || ' do not exist.');
			DBMS_OUTPUT.PUT_LINE('Try again using a number between 1 to 9.');
			checked_skill_id := FALSE;

			RETURN checked_skill_id;	

	END check_skill_id;

FUNCTION check_combination (in_c_id NUMBER, in_skill_id NUMBER)
	RETURN BOOLEAN IS
	checked_consultant BOOLEAN;

	v_cid NUMBER;
	v_skill_id NUMBER;

	BEGIN

		SELECT c_id, skill_id
		INTO v_cid, v_skill_id
		FROM consultant_skill
		WHERE c_id = in_c_id AND skill_id = in_skill_id;
		checked_consultant := TRUE;		

		RETURN checked_consultant;

		EXCEPTION
		WHEN NO_DATA_FOUND THEN
		checked_consultant := FALSE;

		RETURN checked_consultant;

	END check_combination;

FUNCTION certified (in_c_id NUMBER, in_skill_id NUMBER, in_certification VARCHAR2)
	RETURN VARCHAR2 IS
	v_certification VARCHAR2(2);

	BEGIN

		SELECT certification
		INTO v_certification
		FROM consultant_skill
		WHERE c_id = in_c_id AND skill_id = in_skill_id;

		RETURN v_certification;

	END certified;

PROCEDURE update_certification (in_c_id NUMBER, in_skill_id NUMBER, in_certification VARCHAR2) AS

	BEGIN

		UPDATE consultant_skill
		SET certification = in_certification
		WHERE c_id = in_c_id AND skill_id = in_skill_id;
	
	END update_certification;

PROCEDURE insert_certification (in_c_id NUMBER, in_skill_id NUMBER, in_certification VARCHAR2) AS

	BEGIN

		INSERT INTO consultant_skill (c_id, skill_id, certification)
		VALUES (in_c_id,in_skill_id,in_certification);

	END insert_certification;

PROCEDURE print (in_c_id NUMBER, in_skill_id NUMBER) AS
	v_c_last VARCHAR2(20);
	v_c_first VARCHAR2(20);
	v_skill_description VARCHAR2(50);
	v_certification VARCHAR2(2);

	BEGIN
		SELECT c_last, c_first, skill_description, certification
		INTO v_c_last, v_c_first, v_skill_description, v_certification
		FROM consultant cst, consultant_skill css, skill skl
		WHERE cst.c_id = in_c_id AND css.skill_id = in_skill_id AND cst.c_id = css.c_id AND css.skill_id = skl.skill_id;

	DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------');
	DBMS_OUTPUT.PUT_LINE('Consultant last name: ' || v_c_last || '.');
	DBMS_OUTPUT.PUT_LINE('Consultant first name: ' || v_c_first || '.');
	DBMS_OUTPUT.PUT_LINE('Consultant skill description: ' || v_skill_description || '.');
	DBMS_OUTPUT.PUT_LINE('Consultant certification: ' || v_certification || '.');

	END print; 

PROCEDURE update_insert (in_c_id NUMBER, in_skill_id NUMBER, in_certification VARCHAR2) AS
	verify_certification BOOLEAN;
	verify_skill_id BOOLEAN;
	verify_combination BOOLEAN;
	exists_certification VARCHAR2(2);

	BEGIN

		verify_certification := check_certification(in_certification);
		verify_skill_id := check_skill_id(in_skill_id);
		verify_combination := check_combination(in_c_id,in_skill_id);
		
		IF (verify_certification = TRUE) THEN

			IF (verify_skill_id = TRUE) THEN

				IF (verify_combination = TRUE) THEN

					exists_certification := certified(in_c_id,in_skill_id,in_certification);
					IF (exists_certification = in_certification) THEN
					
					PRINT(in_c_id,in_skill_id);
					DBMS_OUTPUT.PUT_LINE('Consultant ' || in_c_id || ' do not need update.');
						
					ELSIF (exists_certification <> in_certification) THEN
					UPDATE_CERTIFICATION(in_c_id,in_skill_id,in_certification);
					PRINT(in_c_id,in_skill_id);
					DBMS_OUTPUT.PUT_LINE('CERTIFICATION UPDATED!!!');
					END IF;	

				ELSIF (verify_combination = FALSE) THEN
				INSERT_CERTIFICATION(in_c_id,in_skill_id,in_certification);
				PRINT(in_c_id,in_skill_id);
				DBMS_OUTPUT.PUT_LINE('CERTIFICATION INSERTED!!!');
				END IF;

			ELSIF (verify_skill_id = FALSE) THEN
			DBMS_OUTPUT.PUT_LINE('---------------------------------');
			END IF;

		ELSIF (verify_certification = FALSE) THEN
		DBMS_OUTPUT.PUT_LINE('----------------------------------');
		END IF;

	EXCEPTION
	WHEN OTHERS THEN
	DBMS_OUTPUT.PUT_LINE('Consultant ' || in_c_id || ' do not exist.');	

	END update_insert;

END;

/

BEGIN 
	consultants_general.update_insert(100,1,'Y');
END;
/

BEGIN 
	consultants_general.update_insert(200,1,'Y');
END;
/

BEGIN 
	consultants_general.update_insert(100,10,'Y');
END;
/

BEGIN 
	consultants_general.update_insert(100,1,'Z');
END;
/

BEGIN 
	consultants_general.update_insert(100,1,'N');
END;
/

BEGIN 
	consultants_general.update_insert(100,1,'N');
END;
/

SPOOL OFF;
