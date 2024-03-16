-- Создание таблицы "Задачи"

CREATE TABLESPACE LABS
    DATAFILE 'labs_datafile.dbf'
    SIZE 100M
    AUTOEXTEND ON
    NEXT 10M
    MAXSIZE UNLIMITED;

alter session set "_ORACLE_SCRIPT"=true;

CREATE USER LABUSER IDENTIFIED BY dima22138
    DEFAULT TABLESPACE LABS
    TEMPORARY TABLESPACE TEMP;

GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE VIEW TO LABUSER;
GRANT UNLIMITED TABLESPACE TO LABUSER;

DROP TABLE TASKS;
DROP TABLE TASK_STEPS;
DROP TABLE PERIODS;
drop table STATUSES;
drop table AUDIT_COMPLETE;

CREATE TABLE TASKS (
                        id NUMBER GENERATED AS IDENTITY PRIMARY KEY,
                        название NVARCHAR2(255),
                        описание NVARCHAR2(2000),
                        период_id NUMBER,
                        статус_задачи_id NUMBER,
                        PPIN NUMBER,
                        FOREIGN KEY (PPIN) REFERENCES PERSONAL(ID),
                        FOREIGN KEY (статус_задачи_id) REFERENCES STATUSES(id),
                        FOREIGN KEY (период_id) REFERENCES PERIODS(id)
);
CREATE TABLE PERIODS (
                         id NUMBER GENERATED AS IDENTITY PRIMARY KEY,
                         дата_начала DATE,
                         дата_окончания DATE
);
CREATE TABLE TASK_STEPS (
                             id NUMBER GENERATED AS IDENTITY PRIMARY KEY,
                             задача_id NUMBER,
                             описание NVARCHAR2(2000),
                             период_id NUMBER,
                             статус_шага_id NUMBER,
                             FOREIGN KEY (статус_шага_id) REFERENCES STATUSES(id),
                             FOREIGN KEY (период_id) REFERENCES PERIODS(id),
                             FOREIGN KEY (задача_id) REFERENCES TASKS(id)
);
CREATE TABLE STATUSES (
                                    id NUMBER GENERATED AS IDENTITY PRIMARY KEY,
                                    описание NVARCHAR2(255)
);
CREATE TABLE AUDIT_COMPLETE (
                                   id NUMBER DEFAULT SEQUENCE_AUDIT_COMPLETE.NEXTVAL PRIMARY KEY,
                                   задача_id NUMBER,
                                   шаг_id NUMBER,
                                   дата TIMESTAMP,
                                   описание NVARCHAR2(2000),
                                   FOREIGN KEY (задача_id) REFERENCES TASKS(id),
                                   FOREIGN KEY (шаг_id) REFERENCES TASK_STEPS (id)
);

CREATE TABLE PERSONAL (
    ID NUMBER GENERATED ALWAYS AS IDENTITY  PRIMARY KEY,
    PARENTID NUMBER,
    FULL_NAME NVARCHAR2(300),
    FOREIGN KEY (PARENTID) REFERENCES PERSONAL(ID)
);

CREATE TABLE SALARY (
                          ID NUMBER GENERATED ALWAYS AS IDENTITY  PRIMARY KEY,
                          PERSON NUMBER,
                          SALARY NUMBER,
                          "DATE" DATE,
                          FOREIGN KEY (PERSON) REFERENCES PERSONAL(ID)
);

DROP TABLE PERSONAL;

--LAB 2

-- Создание представления "Представление_Задачи"
CREATE OR REPLACE VIEW VIEW_TASKS AS
SELECT TASKS.id, TASKS.название, TASKS.описание, PERIODS.дата_начала, PERIODS.дата_окончания
FROM TASKS
         JOIN PERIODS ON TASKS.период_id = PERIODS.id;

CREATE OR REPLACE VIEW COMPLETED_TASKS_VIEW AS
SELECT TASKS.название, TASKS.описание, AUDIT_COMPLETE.дата, STATUSES.описание AS статус_задачи
FROM AUDIT_COMPLETE
         JOIN TASKS ON AUDIT_COMPLETE.задача_id = TASKS.id
         JOIN STATUSES ON TASKS.статус_задачи_id = STATUSES.id;

-- Создание индекса на таблице "Задачи"
CREATE INDEX IX_Задачи_период_id ON TASKS (период_id);

-- Создание последовательности "Последовательность_Журнал_выполнения"
CREATE SEQUENCE SEQUENCE_AUDIT_COMPLETE
    START WITH 1
    INCREMENT BY 1;

-- Создание индексов на таблице "Журнал_выполнения"
CREATE INDEX IX_Журнал_выполнения_задача_id ON AUDIT_COMPLETE (задача_id);
CREATE INDEX IX_Журнал_выполнения_шаг_id ON AUDIT_COMPLETE (шаг_id);

--процедура вычисления кол-ва выполненных шагов в задаче
CREATE OR REPLACE PROCEDURE CALCULATE_COUNT_COMPLETE_TASK_STEPS(
    InputNum IN NUMBER,
    OutputNum OUT NUMBER
)
IS
    COUNT_STEPS NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO OutputNum
    FROM AUDIT_COMPLETE
    WHERE задача_id = InputNum;

    SELECT COUNT(*)
    INTO COUNT_STEPS
    FROM TASK_STEPS
    WHERE задача_id = InputNum;

    DBMS_OUTPUT.PUT_LINE('Количество выполненных шагов в задаче ' || InputNum || ': ' || OutputNum || ' из ' || COUNT_STEPS);
END;

CREATE OR REPLACE PROCEDURE INSERT_TASK(
    название IN NVARCHAR2,
    описание IN NVARCHAR2,
    период_id IN NUMBER,
    статус_задачи_id IN NUMBER
)
AS
BEGIN
    INSERT INTO TASKS (название, описание, период_id, статус_задачи_id)
    VALUES (название, описание, период_id, статус_задачи_id);
    COMMIT;
END;


CREATE OR REPLACE TRIGGER trg_AUDIT_COMPLETE_TASK_STEPS
    AFTER UPDATE OF статус_шага_id ON TASK_STEPS
    FOR EACH ROW
DECLARE
    описание_изменения NVARCHAR2(2000);
BEGIN
    -- Проверка, был ли изменен статус шага задачи
    IF UPDATING('статус_шага_id') THEN
        -- Вставка новой строки в таблицу Журнал_выполнения
        INSERT INTO AUDIT_COMPLETE (задача_id, ШАГ_ID, дата, описание)
        VALUES (:NEW.задача_id, :NEW."ID", SYSDATE, 'Изменен статус шага задачи');
    END IF;
END;

CREATE OR REPLACE TRIGGER trg_AUDIT_COMPLETE_TASKS
    AFTER UPDATE OF статус_задачи_id ON TASKS
    FOR EACH ROW
DECLARE
    описание_изменения NVARCHAR2(2000);
BEGIN
    -- Проверка, был ли изменен статус задачи
    IF UPDATING('статус_задачи_id') THEN
        -- Вставка новой строки в таблицу Журнал_выполнения
        INSERT INTO AUDIT_COMPLETE (задача_id, шаг_id, дата, описание)
        VALUES (:NEW."ID", -1, SYSDATE, 'Изменен статус задачи');
    END IF;
END;

CREATE OR REPLACE FUNCTION COUNT_COMPLETED_STEPS(
    задача_id IN NUMBER
)
    RETURN NUMBER
    IS
    COUNTER NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO COUNTER
    FROM AUDIT_COMPLETE
    WHERE задача_id = задача_id;

    RETURN COUNTER;
END;

CREATE OR REPLACE FUNCTION GET_TASK_DESCRIPTION(
    задача_id IN NUMBER
)
    RETURN NVARCHAR2
    IS
    DESCRIPTION NVARCHAR2(4000);
BEGIN
    SELECT описание
    INTO DESCRIPTION
    FROM TASKS
    WHERE id = задача_id;

    RETURN DESCRIPTION;
END;


-- LAB 3 --
DROP TABLE TEMPTABLE;
CREATE GLOBAL TEMPORARY TABLE TempTable (
    NodeID NUMBER PRIMARY KEY,
    ParentNodeID NUMBER,
    NodeName VARCHAR2(100)
);

INSERT ALL
INTO TempTable (NodeID, ParentNodeID, NodeName) VALUES (1, NULL, 'Node 1')
INTO TempTable (NodeID, ParentNodeID, NodeName) VALUES (2, 1, 'Node 1.1')
INTO TempTable (NodeID, ParentNodeID, NodeName) VALUES(3, 1, 'Node 1.2')
INTO TempTable (NodeID, ParentNodeID, NodeName) VALUES(4, 2, 'Node 1.1.1')
INTO TempTable (NodeID, ParentNodeID, NodeName) VALUES(5, 2, 'Node 1.1.2')
INTO TempTable (NodeID, ParentNodeID, NodeName) VALUES(6, 3, 'Node 1.2.1')
    SELECT * from dual;

SELECT
    NodeID,
    NodeName,
    LEVEL AS NodeLevel
FROM
    TempTable
START WITH
    ParentNodeID IS NULL
CONNECT BY PRIOR
    NodeID = ParentNodeID;

CREATE OR REPLACE PROCEDURE DisplaySubNodes(p_NodeID NUMBER) IS
BEGIN
    FOR rec IN (
        SELECT NodeID, NodeName, LEVEL AS HierarchyLevel, ParentNodeID
        FROM TempTable
        START WITH NodeID = p_NodeID
        CONNECT BY PRIOR NodeID = ParentNodeID
    ) LOOP
            DBMS_OUTPUT.PUT_LINE('NodeID: ' || rec.NodeID || ', NodeName: ' || rec.NodeName || ', HierarchyLevel: ' || TO_CHAR(rec.HierarchyLevel)
                                     || ' Parent '|| rec.ParentNodeId);
    END LOOP;
END;

CREATE OR REPLACE PROCEDURE AddSubNode(p_ParentNodeID NUMBER, p_NodeID NUMBER, p_NodeName VARCHAR2) IS
BEGIN
    INSERT INTO TempTable (NodeID, ParentNodeID, NodeName)
    VALUES (p_NodeID, p_ParentNodeID, p_NodeName);
END;

CREATE OR REPLACE PROCEDURE MoveSubtree (pUpperNodeID NUMBER, pNewParentNodeID NUMBER) AS
BEGIN
    UPDATE TempTable
    SET ParentNodeID = pNewParentNodeID
    WHERE NodeID = pUpperNodeID;
END;

BEGIN
    DisplaySubNodes(p_NodeID => 2);
END;
CALL ADDSUBNODE(7, 8, 'Node 74');
CALL MoveSubTree(3, 2); -- только первый менять


-------LABA 4
--Вычисление итогов заработной платы и численности помесячно, за квартал, за полгода, за год
--отдельный вывод данных месяц квартал, ...
SELECT
    TO_CHAR(s."DATE", 'YYYY') AS "Год",
    CASE
        WHEN TO_CHAR(s."DATE", 'MM') BETWEEN '01' AND '06' THEN '1 полугодие'
        WHEN TO_CHAR(s."DATE", 'MM') BETWEEN '07' AND '12' THEN '2 полугодие'
        END AS "Полугодие",
    TO_CHAR(s."DATE", 'Q') AS "Квартал",
    TO_CHAR(s."DATE", 'YYYY-MM') AS "Месяц",
    COUNT(DISTINCT p.ID) AS "Численность",
    SUM(s.SALARY) AS "Заработная плата"
FROM
    SALARY s
        INNER JOIN PERSONAL p ON s.PERSON = p.ID
GROUP BY
    ROLLUP (
    TO_CHAR(s."DATE", 'YYYY'),
    CASE
        WHEN TO_CHAR(s."DATE", 'MM') BETWEEN '01' AND '06' THEN '1 полугодие'
        WHEN TO_CHAR(s."DATE", 'MM') BETWEEN '07' AND '12' THEN '2 полугодие'
        END,
    TO_CHAR(s."DATE", 'Q'),
    TO_CHAR(s."DATE", 'YYYY-MM')
    )
ORDER BY
    TO_CHAR(s."DATE", 'YYYY'),
    TO_CHAR(s."DATE", 'Q'),
    TO_CHAR(s."DATE", 'YYYY-MM');

------2
--Вычисление итогов выполненных поручений за определенный период:
--•	количество выполненных поручений;
--•	сравнение их с общим количеством выполненных поручений (в %);
--•	сравнение с общим количеством не выполненных поручений (в %).
--TODO COMPLETED
SELECT
    общее_количество_поручений,
        (выполненные_поручения / общее_количество_поручений) * 100 AS процент_выполненных_поручений,
        (общее_количество_не_выполненных_поручений / общее_количество_поручений) * 100 AS процент_не_выполненных_поручений
FROM
    (SELECT
         SUM(CASE WHEN t.статус_задачи_id = 1 THEN 1 ELSE 0 END) AS выполненные_поручения,
         COUNT(*) AS общее_количество_поручений,
         SUM(CASE WHEN t.статус_задачи_id = 2 THEN 1 ELSE 0 END) AS общее_количество_не_выполненных_поручений
     FROM
         TASKS t
             LEFT JOIN AUDIT_COMPLETE a ON t.id = a.задача_id
     INNER JOIN PERIODS P on P.id = t.период_id
     WHERE
             P.дата_начала >= TO_TIMESTAMP('2023-09-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
       AND P.дата_окончания <= TO_TIMESTAMP('2024-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')) подзапрос;

---3
--Продемонстрируйте применение функции ранжирования ROW_NUMBER() для разбиения результатов запроса на страницы (по 20 строк на каждую страницу).
SELECT *
    FROM (
             SELECT
                 id,
                 название,
                 описание,
                 ROW_NUMBER() OVER (ORDER BY id) AS row_num
             FROM
                 TASKS
         ) numbered_rows
    WHERE
        row_num BETWEEN ((:page_number - 1) * :coun + 1) AND (:page_number * :coun);


--4
-- Продемонстрируйте применение функции ранжирования ROW_NUMBER() для удаления дубликатов.
SELECT id, название, описание, период_id, статус_задачи_id
FROM (
         SELECT
             id, название, описание, период_id, статус_задачи_id,
             ROW_NUMBER() OVER (PARTITION BY название, описание ORDER BY id) AS row_num
         FROM TASKS
     ) t
WHERE row_num = 1;

--5
--Вернуть для каждого сотрудника количество выполненных и не выполненных заданий за последние 6 месяцев помесячно.
SELECT
    P.FULL_NAME,
    EXTRACT(YEAR FROM AC.дата) AS Год,
    EXTRACT(MONTH FROM AC.дата) AS Месяц,
    COUNT(CASE WHEN TS.статус_шага_id = выполнено_id THEN 1 END) AS Выполнено,
    COUNT(CASE WHEN TS.статус_шага_id = не_выполнено_id THEN 1 END) AS Не_выполнено
FROM
    PERSONAL P
        LEFT JOIN
    TASKS T ON P.ID = T.PPIN
        LEFT JOIN
    TASK_STEPS TS ON T.ID = TS.задача_id
        LEFT JOIN
    AUDIT_COMPLETE AC ON TS.ID = AC.шаг_id
        LEFT JOIN
    STATUSES S ON TS.статус_шага_id = S.ID
        CROSS JOIN
    (
        SELECT
            ID AS выполнено_id
        FROM
            STATUSES
        WHERE
                описание = 'выполнено'
    ) выполнено
        CROSS JOIN
    (
        SELECT
            ID AS не_выполнено_id
        FROM
            STATUSES
        WHERE
                описание = 'не выполнено'
    ) не_выполнено
WHERE
        AC.дата >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -6)
GROUP BY
    P.FULL_NAME,
    EXTRACT(YEAR FROM AC.дата),
    EXTRACT(MONTH FROM AC.дата)
ORDER BY
    P.FULL_NAME,
    Год,
    Месяц;

--6
--Какой сотрудник выполнил *наибольшее число* поручений определенного вида? Вернуть для всех видов.
---так и надо чтобы работало
WITH counted_tasks AS (
    SELECT
        P.FULL_NAME,
        S.описание AS Вид_поручения,
        COUNT(*) AS Количество_поручений,
        RANK() OVER (PARTITION BY S.описание ORDER BY COUNT(*) DESC) AS Ранж
    FROM
        PERSONAL P
            INNER JOIN
        TASKS T ON P.ID = T.PPIN
            INNER JOIN
        STATUSES S ON T.статус_задачи_id = S.ID
    GROUP BY
        P.FULL_NAME,
        S.описание
)
SELECT
    FULL_NAME,
    Вид_поручения,
    Количество_поручений
FROM
    counted_tasks
WHERE
        Ранж = 1;

--LAb 5
SELECT * FROM DIMENS;




--LABA 6
--1
CREATE OR REPLACE PROCEDURE calculate_salary_bonus (person_id IN NUMBER) AS
    bonus_amount NUMBER;
BEGIN
    -- Логика расчета бонуса
    -- Пример: Если зарплата больше 5000, то бонус составляет 10% от зарплаты
    SELECT Sum(SALARY * 0.1) INTO bonus_amount FROM SALARY WHERE PERSON = person_id;

    -- Вывод результата
    DBMS_OUTPUT.PUT_LINE('Бонус для сотрудника с ID ' || person_id || ': ' || bonus_amount);
END;
/

CREATE OR REPLACE FUNCTION get_task_count RETURN NUMBER AS
    task_count NUMBER;
BEGIN
    -- Получение количества задач
    SELECT COUNT(*) INTO task_count FROM TASKS;

    -- Возвращение результата
    RETURN task_count;
END;
/

--2
DECLARE
    person_id NUMBER := 1;
    task_count NUMBER;
BEGIN
    -- Выполнение процедуры
    calculate_salary_bonus(person_id);

    -- Выполнение функции
    task_count := get_task_count;
    DBMS_OUTPUT.PUT_LINE('Количество задач: ' || task_count);
END;
/


--3
CREATE OR REPLACE PROCEDURE update_task_description (task_id IN NUMBER, new_description IN NVARCHAR2) AS
BEGIN
    -- Обновление описания задачи
    UPDATE TASKS SET описание = new_description WHERE id = task_id;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        -- Обработка ошибки
        DBMS_OUTPUT.PUT_LINE('Ошибка при обновлении описания задачи: ' || SQLERRM);
END;
/

CREATE OR REPLACE PROCEDURE get_completed_tasks (out_cursor OUT SYS_REFCURSOR) AS
BEGIN
    -- Получение списка выполненных задач
    OPEN out_cursor FOR
        SELECT * FROM TASKS WHERE id IN (SELECT задача_id FROM AUDIT_COMPLETE);
EXCEPTION
    WHEN OTHERS THEN
        -- Обработка ошибки
        DBMS_OUTPUT.PUT_LINE('Ошибка при получении выполненных задач: ' || SQLERRM);
END;
/

--4
DECLARE
    task_id NUMBER := 1;
    new_description NVARCHAR2(2000) := 'Новое описание задачи';

    completed_tasks_cursor SYS_REFCURSOR;
    completed_task TASKS%ROWTYPE;
BEGIN
    -- Выполнение процедуры обновления описания задачи
    update_task_description(task_id, new_description);

    -- Выполнение процедуры получения выполненных задач
    get_completed_tasks(completed_tasks_cursor);

    -- Вывод результатов
    LOOP
        FETCH completed_tasks_cursor INTO completed_task;
        EXIT WHEN completed_tasks_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('ID: ' || completed_task.id || ', Название: ' || completed_task.название);
    END LOOP;

    -- Закрытие курсора
    CLOSE completed_tasks_cursor;
END;
/

--5
CREATE OR REPLACE FUNCTION calculate_average_salary RETURN NUMBER AS
    avg_salary NUMBER;
BEGIN
    -- Вычисление средней зарплаты
    SELECT AVG(SALARY) INTO avg_salary FROM SALARY;

    -- Возвращение результата
    RETURN avg_salary;
END;
/

CREATE OR REPLACE FUNCTION calculate_date_diff(start_date IN DATE, end_date IN DATE) RETURN NUMBER AS
    diff_in_days NUMBER;
BEGIN
    -- Вычисление разницы между датами в днях
    diff_in_days := end_date - start_date;

    -- Возвращение результата
    RETURN diff_in_days;
END;
/

--6
DECLARE
    average_salary NUMBER;
    start_date DATE := TO_DATE('2023-01-01', 'YYYY-MM-DD');
    end_date DATE := TO_DATE('2023-12-31', 'YYYY-MM-DD');
    date_diff NUMBER;
BEGIN
    -- Выполнение функции вычисления средней зарплаты
    average_salary := calculate_average_salary;
    DBMS_OUTPUT.PUT_LINE('Средняя зарплата: ' || average_salary);

    -- Выполнение функции вычисления разницы между датами
    date_diff := calculate_date_diff(start_date, end_date);
    DBMS_OUTPUT.PUT_LINE('Разница между датами: ' || date_diff || ' дней');
END;
/

--7
SELECT calculate_average_salary() AS avg_salary FROM DUAL;
SELECT calculate_date_diff(TO_DATE('2023-01-01', 'YYYY-MM-DD'), TO_DATE('2023-12-31', 'YYYY-MM-DD')) AS date_diff FROM DUAL;

--8
CREATE OR REPLACE PACKAGE my_package AS
    PROCEDURE calculate_salary_bonus (person_id IN NUMBER);
    FUNCTION get_task_count RETURN NUMBER;
    PROCEDURE update_task_description (task_id IN NUMBER, new_description IN NVARCHAR2);
    PROCEDURE get_completed_tasks (out_cursor OUT SYS_REFCURSOR);
    FUNCTION calculate_average_salary RETURN NUMBER;
    FUNCTION calculate_date_diff(start_date IN DATE, end_date IN DATE) RETURN NUMBER;
END my_package;
/

CREATE OR REPLACE PACKAGE BODY my_package AS
    PROCEDURE calculate_salary_bonus (person_id IN NUMBER) AS
        bonus_amount NUMBER;
    BEGIN
        -- Логика расчета бонуса
        -- Пример: Если зарплата больше 5000, то бонус составляет 10% от зарплаты
        SELECT SUM(SALARY * 0.1) INTO bonus_amount FROM SALARY WHERE PERSON = person_id;

        -- Вывод результата
        DBMS_OUTPUT.PUT_LINE('Бонус для сотрудника с ID ' || person_id || ': ' || bonus_amount);
    END;

    FUNCTION get_task_count RETURN NUMBER AS
        task_count NUMBER;
    BEGIN
        -- Получение количества задач
        SELECT COUNT(*) INTO task_count FROM TASKS;

        -- Возвращение результата
        RETURN task_count;
    END;

    PROCEDURE update_task_description (task_id IN NUMBER, new_description IN NVARCHAR2) AS
    BEGIN
        -- Обновление описания задачи
        UPDATE TASKS SET описание = new_description WHERE id = task_id;
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            -- Обработка ошибки
            DBMS_OUTPUT.PUT_LINE('Ошибка при обновлении описания задачи: ' || SQLERRM);
    END;

    PROCEDURE get_completed_tasks (out_cursor OUT SYS_REFCURSOR) AS
    BEGIN
        -- Получение списка выполненных задач
        OPEN out_cursor FOR
        SELECT * FROM TASKS WHERE статус_задачи_id = 1;
    EXCEPTION
        WHEN OTHERS THEN
            -- Обработка ошибки
            DBMS_OUTPUT.PUT_LINE('Ошибка при получении выполненных задач: ' || SQLERRM);
    END;

    FUNCTION calculate_average_salary RETURN NUMBER AS
        avg_salary NUMBER;
    BEGIN
        -- Вычисление средней зарплаты
        SELECT AVG(SALARY) INTO avg_salary FROM SALARY;

        -- Возвращение результата
        RETURN avg_salary;
    END;

    FUNCTION calculate_date_diff(start_date IN DATE, end_date IN DATE) RETURN NUMBER AS
        diff_in_days NUMBER;
    BEGIN
        -- Вычисление разницы между датами в днях
        diff_in_days := end_date - start_date;

        -- Возвращение результата
        RETURN diff_in_days;
    END;
END my_package;
/

--9
DECLARE
    person_id NUMBER := 1;
    task_count NUMBER;
    completed_tasks_cursor SYS_REFCURSOR;
    completed_task TASKS%ROWTYPE;
    average_salary NUMBER;
    start_date DATE := TO_DATE('2023-01-01', 'YYYY-MM-DD');
    end_date DATE := TO_DATE('2023-12-31', 'YYYY-MM-DD');
    date_diff NUMBER;
BEGIN
    -- Вызов процедур из пакета
    my_package.calculate_salary_bonus(person_id);
    task_count := my_package.get_task_count;
    my_package.update_task_description(1, 'Новое описание задачи');
    my_package.get_completed_tasks(completed_tasks_cursor);

    -- Вывод результатов
    LOOP
        FETCH completed_tasks_cursor INTO completed_task;
        EXIT WHEN completed_tasks_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('ID: ' || completed_task.id || ', Название: ' || completed_task.название);
    END LOOP;
    CLOSE completed_tasks_cursor;

    -- Вызов функций из пакета
    average_salary := my_package.calculate_average_salary;
    date_diff := my_package.calculate_date_diff(start_date, end_date);

    DBMS_OUTPUT.PUT_LINE('Средняя зарплата: ' || average_salary);
    DBMS_OUTPUT.PUT_LINE('Разница между датами: ' || date_diff || ' дней');
END;
/















--Lab 8
-- Создание объектного типа данных "Поручение"
CREATE OR REPLACE TYPE TaskType AS OBJECT (
                                              id NUMBER,
                                              название NVARCHAR2(255),
                                              описание NVARCHAR2(2000),
                                              период_id NUMBER,
                                              статус_задачи_id NUMBER,
                                              PPIN NUMBER,
                                              CONSTRUCTOR FUNCTION TaskType RETURN SELF AS RESULT,
                                              ORDER MEMBER FUNCTION compare(o IN TaskType) RETURN NUMBER,
                                              MEMBER FUNCTION getInfo RETURN NVARCHAR2 DETERMINISTIC
                                          );
/

-- Создание конструктора для типа данных "Поручение"
CREATE OR REPLACE TYPE BODY TaskType AS
    CONSTRUCTOR FUNCTION TaskType RETURN SELF AS RESULT IS
    BEGIN
        SELF.id := NULL;
        SELF.название := NULL;
        SELF.описание := NULL;
        SELF.период_id := NULL;
        SELF.статус_задачи_id := NULL;
        SELF.PPIN := NULL;
        RETURN;
    END;

    -- Метод сравнения типа данных "Поручение"
    ORDER MEMBER FUNCTION compare(o IN TaskType) RETURN NUMBER IS
    BEGIN
        IF SELF.id < o.id THEN
            RETURN -1;
        ELSIF SELF.id > o.id THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    END;

    -- Метод, возвращающий информацию о типе данных "Поручение"
    MEMBER FUNCTION getInfo RETURN NVARCHAR2 DETERMINISTIC IS
    BEGIN
        RETURN 'Task ID: ' || TO_CHAR(SELF.id) || ', Название: ' || SELF.название;
    END;
END;
/

-- Создание объектного типа данных "Исполнитель"
CREATE OR REPLACE TYPE ExecutorType AS OBJECT (
                                                  id NUMBER,
                                                  ФИО NVARCHAR2(300),
                                                  CONSTRUCTOR FUNCTION ExecutorType RETURN SELF AS RESULT,
                                                  MEMBER PROCEDURE executeTask(task IN TaskType),
                                                  MAP MEMBER FUNCTION getFullName RETURN NVARCHAR2 DETERMINISTIC
                                              );
/

-- Создание конструктора для типа данных "Исполнитель"
CREATE OR REPLACE TYPE BODY ExecutorType AS
    CONSTRUCTOR FUNCTION ExecutorType RETURN SELF AS RESULT IS
    BEGIN
        SELF.id := NULL;
        SELF.ФИО := NULL;
        RETURN;
    END;

    -- Метод, выполняющий поручение
    MEMBER PROCEDURE executeTask(task IN TaskType) IS
    BEGIN
        -- Логика выполнения поручения
        DBMS_OUTPUT.PUT_LINE('Исполнитель ' || SELF.ФИО || ' выполняет поручение ' || task.название);
    END;

    -- Метод, возвращающий полное имя исполнителя
    MAP MEMBER FUNCTION getFullName RETURN NVARCHAR2 DETERMINISTIC IS
    BEGIN
        RETURN SELF.ФИО;
    END;
END;
/

-- Пример применения объектных представлений
-- Объектное представление для таблицы TASKS
CREATE OR REPLACE VIEW task_view AS
SELECT TaskType(
               id,
               название,
               описание,
               период_id,
               статус_задачи_id,
               PPIN
           ) AS task_obj
FROM TASKS
;
select * from task_view;

-- Объектное представление для таблицы PERSONAL
CREATE OR REPLACE VIEW personal_view AS
SELECT ExecutorType(
               ID,
               FULL_NAME
           ) AS executor_obj
FROM PERSONAL
;

-- Копирование данных из реляционных таблиц в объектные
drop Table Tasks_obj_table;
DROP TABLE Executor_OBJ_T;
CREATE TABLE TASKS_OBJ_TABLE (
    task_obj TaskType
);
CREATE Table Executor_OBJ_T(
    exe_obj EXECUTORTYPE
);
INSERT INTO TASKS_OBJ_TABLE
SELECT TaskType(
               id,
               название,
               описание,
               период_id,
               статус_задачи_id,
               PPIN
           )
FROM TASKS;
INSERT INTO EXECUTOR_OBJ_T
SELECT ExecutorType(ID, FULL_NAME)
FROM PERSONAL;

Select * from TASKS_OBJ_TABLE;
SELECT * FROM EXECUTOR_OBJ_T;

-- Пример применения индексов для индексирования по атрибуту и по методу в объектной таблице
CREATE INDEX task_name_idx ON TASKS_OBJ_TABLE (task_obj.НАЗВАНИЕ);
CREATE INDEX EXE_name_idx ON EXECUTOR_OBJ_T (exe_obj.ФИО);

CREATE INDEX task_GINFO_idx ON TASKS_OBJ_TABLE(task_obj.GETINFO()); -- НЕ СМОГ ПЕРЕСОЗДАТЬ ТИП(ЧТО-ТО МЕШАЕТ, А ЧТО, ХЗ)
CREATE INDEX EXE_GFULLNAME_IDX ON EXECUTOR_OBJ_T(EXE_OBJ.GETFULLNAME());







--LABA 11
create USER MIGGRat IDENTIFIED BY password
    DEFAULT TABLESPACE LABS
    TEMPORARY TABLESPACE TEMP;

Grant resource, connect, create session, create view, create any trigger, create any procedure, create any table to MIGGRat;
GRANT ALL PRIVILEGES TO LABUSER;
GRANT UNLIMITED TABLESPACE TO MIGGRAT;