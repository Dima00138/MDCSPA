use master;

Create DATABASE Univ;

use Univ;

DROP TABLE Task;
DROP TABLE Periodes;
DROP TABLE TaskStep;
drop table Statuse;
drop table CompleteList;

-- Создание таблицы "Задачи"
CREATE TABLE Task (
                        id INT IDENTITY(1,1) PRIMARY KEY,
                        Name NVARCHAR(255),
                        [desc] NVARCHAR(MAX),
                        per_id INT,
                        stat_id INT,
                        FOREIGN KEY (stat_id) REFERENCES Statuse(id),
                        FOREIGN KEY (per_id) REFERENCES Periodes (id)
);

-- Создание таблицы "Периоды"
CREATE TABLE Periodes (
                         id INT IDENTITY(1,1) PRIMARY KEY,
                         date_beg DATE,
                         date_end DATE
);

-- Создание таблицы "Шаги_задачи"
CREATE TABLE TaskStep (
                             id INT IDENTITY(1,1) PRIMARY KEY,
                             task_id INT,
                             [desc] NVARCHAR(MAX),
                             per_id INT,
                             stat_id INT,
                             FOREIGN KEY (stat_id) REFERENCES Statuse(id),
                             FOREIGN KEY (per_id) REFERENCES Periodes (id),
                             FOREIGN KEY (task_id) REFERENCES Task (id)
);

-- Создание таблицы "Статусы_задач"
CREATE TABLE Statuse (
                               id INT IDENTITY(1,1) PRIMARY KEY,
                               описание NVARCHAR(255),
);

-- Создание таблицы "Журнал_выполнения"
CREATE TABLE CompleteList (
                                   id INT IDENTITY(1,1) PRIMARY KEY,
                                   task_id INT,
                                   step_id INT,
                                   dateE DATETIME,
                                   [desc] NVARCHAR(MAX),
                                   FOREIGN KEY (task_id) REFERENCES Task (id),
                                   FOREIGN KEY (step_id) REFERENCES TaskStep (id)
);
CREATE TABLE PERSONAL (
                          ID INT IDENTITY(1,1) PRIMARY KEY,
                          PARENTID INT,
                          FULL_NAME NVARCHAR(300)
);

CREATE TABLE SALARY (
                        ID INT IDENTITY(1,1) PRIMARY KEY,
                        PERSON INT,
                        SALARY INT,
                        [DATE] DATE,
                        FOREIGN KEY (PERSON) REFERENCES PERSONAL(ID) ON DELETE CASCADE
);
--LAB 2


-- Создание представления "Представление_Задачи"
CREATE OR ALTER VIEW TASKS_VIEW
AS
SELECT Task.id, Task.Name, Task.[desc], Periodes.date_beg, Periodes.date_end
FROM Task
         JOIN Periodes ON Task.per_id = Periodes.id;

CREATE OR ALTER VIEW COMPLETED_TASKS_VIEW
AS
SELECT Task.Name, Task.[desc], CompleteList.dateE, Statuse.описание AS статус_задачи
FROM CompleteList
         JOIN Task ON CompleteList.task_id = Task.id
         JOIN Statuse ON Task.stat_id = Statuse.id;

-- Создание индекса на таблице "Задачи"
CREATE INDEX IX_Задачи_период_id ON Task (per_id);

-- Создание индекса на таблице "Журнал_выполнения"
CREATE INDEX IX_Журнал_выполнения_задача_id ON CompleteList (task_id);
CREATE INDEX IX_Журнал_выполнения_шаг_id ON CompleteList (step_id);

CREATE OR ALTER PROCEDURE CALCULATE_COUNT_COMPLETE_TASK_STEPS
    @входной_идентификатор_задачи INT,
    @выходное_количество INT OUTPUT
AS
BEGIN
    SELECT @выходное_количество = COUNT(*)
    FROM CompleteList
    WHERE task_id = @входной_идентификатор_задачи;

    PRINT 'Количество выполненных шагов в задаче ' + CAST(@входной_идентификатор_задачи AS NVARCHAR(50)) + ': ' + CAST(@выходное_количество AS NVARCHAR(50));
END;

GO;

CREATE OR ALTER PROCEDURE INSERT_TASK(
        @название NVARCHAR(255),
        @описание NVARCHAR(MAX),
        @период_id INT,
        @статус_задачи_id INT
    )
AS
BEGIN
        INSERT INTO Task (Name, [desc], per_id, stat_id)
        VALUES (@название, @описание, @период_id, @статус_задачи_id);
END;

CREATE OR ALTER FUNCTION GET_TASK_DESCRIPTION(@задача_id INT)
        RETURNS NVARCHAR(MAX)
AS
BEGIN
        DECLARE @описание NVARCHAR(MAX);
        SELECT @описание = [desc]
        FROM Task
        WHERE id = @задача_id;
        RETURN @описание;
END;

CREATE OR ALTER FUNCTION COUNT_COMPLETED_STEPS(@задача_id INT)
        RETURNS INT
AS
BEGIN
        DECLARE @количество INT;
        SELECT @количество = COUNT(*)
        FROM CompleteList
        WHERE task_id = @задача_id;
        RETURN @количество;
END;

GO;

CREATE TRIGGER trg_CompleteList_Task_Steps
    ON TaskStep
    AFTER UPDATE
    AS
BEGIN
    -- Проверка, был ли изменен статус шага задачи
    IF UPDATE(stat_id)
        BEGIN
            -- Вставка новой строки в таблицу Журнал_выполнения
            INSERT INTO CompleteList (task_id, step_id, dateE, [desc])
            SELECT i.task_id,
                   i.id,
                   GETDATE() AS дата,
                   'Изменен статус шага задачи' AS описание
            FROM inserted i
                     INNER JOIN deleted d ON i.id = d.id

        END
END;
GO;
drop trigger trg_Журнал_выполнения_Tasks;
CREATE TRIGGER trg_CompleteList_Tasks
    ON Task
    AFTER UPDATE
    AS
BEGIN
    -- Проверка, был ли изменен статус задачи
    IF UPDATE(stat_id)
        BEGIN
            -- Вставка новой строки в таблицу Журнал_выполнения
            INSERT INTO CompleteList (task_id, step_id, dateE, [desc])
            SELECT i.id,
                   -1 AS шаг_id,
                   GETDATE() AS дата,
                   'Изменен статус задачи' AS описание
            FROM inserted i
                     INNER JOIN deleted d ON i.id = d.id

        END
END;
GO;


-- LAB 3 --

CREATE TABLE #TempTable
(
    ID INT,
    ParentID INT,
    HierarchyColumn HierarchyID,
    Name VARCHAR(100)
);

Delete from #TempTable;

INSERT INTO #TempTable (ID, ParentID, HierarchyColumn, Name)
VALUES
    (1, NULL, HierarchyID::GetRoot(), 'Node 1'),
    (2, 1, HierarchyID::Parse('/1/'), 'Node 1.1'),
    (3, 1, HierarchyID::Parse('/2/'), 'Node 1.2'),
    (4, 2, HierarchyID::Parse('/1/1/'), 'Node 1.1.1'),
    (5, 2, HierarchyID::Parse('/1/2/'), 'Node 1.1.2'),
    (6, 3, HierarchyID::Parse('/2/1/'), 'Node 1.2.1');

CREATE PROCEDURE GetSubordinateNodes
    @NodeValue HierarchyID
AS
BEGIN
    SELECT
        HierarchyColumn.ToString() AS NodePath,
        HierarchyColumn.GetLevel() AS NodeLevel
    FROM
        #TempTable
    WHERE
        HierarchyColumn.IsDescendantOf(@NodeValue) = 1
    ORDER BY
        NodeLevel,
        NodePath;
END;
GO;
drop PROCEDURE AddSubordinateNode;
CREATE PROCEDURE AddSubordinateNode
@NewNodeValue HierarchyID,
@Node HIERARCHYID
AS
BEGIN
    -- Проверяем, существует ли узел @NewNodeValue
    IF EXISTS (SELECT * FROM #TempTable WHERE HierarchyColumn = @NewNodeValue.GetAncestor(1))
        BEGIN
            -- Если узел @NewNodeValue.GetAncestor(1) существует, добавляем узел @NewNodeValue
            INSERT INTO #TempTable (ID, ParentID, HierarchyColumn, Name)
            SELECT
                (SELECT MAX(ID) + 1 FROM #TempTable),
                (SELECT ParentID FROM #TempTable WHERE HierarchyColumn = @Node),
                @Node.GetDescendant(@NewNodeValue, NULL),
                'New Node'
        END
    ELSE
        BEGIN
            -- Если узел @NewNodeValue.GetAncestor(1) не существует, добавляем узел @NewNodeValue.GetAncestor(1)
            INSERT INTO #TempTable (ID, ParentID, HierarchyColumn, Name)
            SELECT
                (SELECT MAX(ID) + 1 FROM #TempTable),
                NULL,
                @NewNodeValue.GetAncestor(1),
                'New Node'
        END
END;
GO;
drop PROCEDURE MoveSubordinateBranch;
CREATE PROCEDURE MoveSubordinateBranch
    @SourceNodeValue HierarchyID,
    @DestinationNodeValue HierarchyID
AS
BEGIN
    DECLARE @SubordinateNodes TABLE (HierarchyColumn HierarchyID)
    DECLARE  @parent int

    -- Получаем все подчиненные узлы
    INSERT INTO @SubordinateNodes
    SELECT HierarchyColumn
    FROM #TempTable
    WHERE HierarchyColumn.IsDescendantOf(@SourceNodeValue) = 1

    SELECT @parent = ID
    FROM #TempTable
    WHERE HierarchyColumn = @DestinationNodeValue

    UPDATE #TempTable
    SET ParentID = @parent
    where HierarchyColumn = @SourceNodeValue

    UPDATE sn
    SET HierarchyColumn = HierarchyColumn.GetReparentedValue(@SourceNodeValue, @DestinationNodeValue)
    FROM @SubordinateNodes sn

    UPDATE #TempTable
    SET HierarchyColumn = sn.HierarchyColumn
    FROM @SubordinateNodes sn
    WHERE #TempTable.HierarchyColumn = sn.HierarchyColumn
END
GO

EXEC AddSubordinateNode '/2/2/2/', '/2/2/' --передeлать /2/1/ -> /2/2/ --TODO Complete
EXEC GetSubordinateNodes '/1/'
EXEC MoveSubordinateBranch '/2/', '/1/'

GO;
WITH RecursiveHierarchy AS (
    SELECT ID, ParentID, HierarchyColumn, Name, 1 AS Level
    FROM #TempTable
    WHERE ParentID IS NULL

    UNION ALL

    SELECT t.ID, t.ParentID, t.HierarchyColumn, t.Name, rh.Level + 1
    FROM #TempTable t
             INNER JOIN RecursiveHierarchy rh ON t.ParentID = rh.ID
)
SELECT
        REPLICATE('    ', Level - 1) + HierarchyColumn.ToString() AS IndentedHierarchy,
        Name
FROM RecursiveHierarchy
ORDER BY HierarchyColumn;

select * from #TempTable;

----Laba 4
-----1
-- SELECT
--     CONVERT(varchar(4), s.[DATE], 121) AS [Год],
--     CONVERT(varchar(1), DATEPART(QUARTER, s.[DATE])) AS [Квартал],
--     CONVERT(varchar(7), s.[DATE], 121) AS [Месяц],
--     CASE
--         WHEN DATEPART(MONTH, s.[DATE]) BETWEEN 1 AND 4 THEN '1 квартал'
--         WHEN DATEPART(MONTH, s.[DATE]) BETWEEN 5 AND 8 THEN '2 квартал'
--         WHEN DATEPART(MONTH, s.[DATE]) BETWEEN 9 AND 12 THEN '3 квартал'
--         END AS [Период],
--     COUNT(DISTINCT p.ID) AS [Численность],
--     SUM(s.SALARY) AS [Заработная плата]
-- FROM
--     SALARY s
--         INNER JOIN PERSONAL p ON s.PERSON = p.ID
-- GROUP BY
--     GROUPING SETS (
--     (CONVERT(varchar(4), s.[DATE], 121)),
--     (CONVERT(varchar(1), DATEPART(QUARTER, s.[DATE]))),
--     (CONVERT(varchar(7), s.[DATE], 121)),
--     (CASE
--          WHEN DATEPART(MONTH, s.[DATE]) BETWEEN 1 AND 4 THEN '1 квартал'
--          WHEN DATEPART(MONTH, s.[DATE]) BETWEEN 5 AND 8 THEN '2 квартал'
--          WHEN DATEPART(MONTH, s.[DATE]) BETWEEN 9 AND 12 THEN '3 квартал'
--         END)
--     )
-- ORDER BY
--     CONVERT(varchar(4), s.[DATE], 121),
--     CONVERT(varchar(1), DATEPART(QUARTER, s.[DATE])),
--     CONVERT(varchar(7), s.[DATE], 121);
--
--
-- ---------2
-- WITH Выполненные AS (
--     SELECT COUNT(DISTINCT З.id) AS КоличествоВыполненных
--     FROM Задачи З
--              INNER JOIN Журнал_выполнения ЖВ ON З.id = ЖВ.задача_id
--     WHERE З.статус_задачи_id = (SELECT id FROM Статусы_выполнения WHERE описание = 'Выполнено')
-- ),
--      Общие AS (
--          SELECT COUNT(DISTINCT З.id) AS КоличествоОбщее
--          FROM Задачи З
--                   INNER JOIN Журнал_выполнения ЖВ ON З.id = ЖВ.задача_id
--      )
-- SELECT
--     Выполненные.КоличествоВыполненных AS Выполненные_поручения,
--     (Выполненные.КоличествоВыполненных / Общие.КоличествоОбщее) * 100 AS Процент_Выполненных,
--     ((Общие.КоличествоОбщее - Выполненные.КоличествоВыполненных) / Общие.КоличествоОбщее) * 100 AS Процент_Не_Выполненных
-- FROM
--     Выполненные, Общие;
--
--
-- ---------6
-- WITH Выполненные AS (
--     SELECT
--         З.сотрудник_id,
--         YEAR(ЖВ.дата) AS Год,
--         MONTH(ЖВ.дата) AS Месяц,
--         COUNT(DISTINCT З.id) AS КоличествоВыполненных
--     FROM
--         Задачи З
--             INNER JOIN Журнал_выполнения ЖВ ON З.id = ЖВ.задача_id
--     WHERE
--             З.статус_задачи_id = (SELECT id FROM Статусы_выполнения WHERE описание = 'Выполнено')
--       AND ЖВ.дата >= DATEADD(MONTH, -6, GETDATE())
--     GROUP BY
--         З.сотрудник_id,
--         YEAR(ЖВ.дата),
--         MONTH(ЖВ.дата)
-- ),
--      Не_Выполненные AS (
--          SELECT
--              З.сотрудник_id,
--              YEAR(ЖВ.дата) AS Год,
--              MONTH(ЖВ.дата) AS Месяц,
--              COUNT(DISTINCT З.id) AS КоличествоНеВыполненных
--          FROM
--              Задачи З
--                  LEFT JOIN Журнал_выполнения ЖВ ON З.id = ЖВ.задача_id
--          WHERE
--                  З.статус_задачи_id <> (SELECT id FROM Статусы_выполнения WHERE описание = 'Выполнено')
--            AND (ЖВ.дата IS NULL OR ЖВ.дата >= DATEADD(MONTH, -6, GETDATE()))
--          GROUP BY
--              З.сотрудник_id,
--              YEAR(ЖВ.дата),
--              MONTH(ЖВ.дата)
--      )
-- SELECT
--     В.сотрудник_id,
--     В.Год,
--     В.Месяц,
--     COALESCE(В.КоличествоВыполненных, 0) AS Выполненные_задания,
--     COALESCE(НВ.КоличествоНеВыполненных, 0) AS Не_Выполненные_задания
-- FROM
--     Выполненные В
--         FULL JOIN Не_Выполненные НВ ON В.сотрудник_id = НВ.сотрудник_id AND В.Год = НВ.Год AND В.Месяц = НВ.Месяц
-- ORDER BY
--     В.сотрудник_id,
--     В.Год DESC,
--     В.Месяц DESC;
--
-- -----7
-- WITH Выполненные AS (
--     SELECT
--         З.сотрудник_id,
--         З.вид_поручения_id,
--         COUNT(DISTINCT З.id) AS КоличествоВыполненных
--     FROM
--         Задачи З
--             INNER JOIN Журнал_выполнения ЖВ ON З.id = ЖВ.задача_id
--     WHERE
--             З.статус_задачи_id = (SELECT id FROM Статусы_выполнения WHERE описание = 'Выполнено')
--     GROUP BY
--         З.сотрудник_id,
--         З.вид_поручения_id
-- ),
--      Наибольший_Поручения AS (
--          SELECT
--              В.вид_поручения_id,
--              MAX(В.КоличествоВыполненных) AS МаксимальноеКоличество
--          FROM
--              Выполненные В
--          GROUP BY
--              В.вид_поручения_id
--      )
-- SELECT
--     НП.вид_поручения_id,
--     НП.МаксимальноеКоличество AS Выполненные_Поручения,
--     ВП.сотрудник_id AS Идентификатор_Сотрудника
-- FROM
--     Наибольший_Поручения НП
--         INNER JOIN Выполненные ВП ON НП.вид_поручения_id = ВП.вид_поручения_id AND НП.МаксимальноеКоличество = ВП.КоличествоВыполненных;

--
-- 1)SELECT    STUDENT.NAME,    YEAR(MARK.MARK_DATE) AS Year,    MONTH(MARK.MARK_DATE) AS Month,    AVG(MARK.MARK) AS 'Month mark'FROM MARKJOIN STUDENT on MARK.STUDENT_ID = STUDENT.STUDENT_IDWHERE MARK.MARK_DATE BETWEEN '2021-09-01' AND '2022-05-31'GROUP BY    STUDENT.NAME, YEAR(MARK.MARK_DATE), MONTH(MARK.MARK_DATE);SELECT    STUDENT.NAME,    YEAR(MARK.MARK_DATE) AS Year,    CASE        WHEN MONTH(MARK.MARK_DATE) IN (9, 10, 11) THEN 'Sep-Nov'        WHEN MONTH(MARK.MARK_DATE) IN (12, 1, 2) THEN 'Dec-Feb'        ELSE 'Mar-May'    END AS Quarter,    AVG(MARK.MARK) AS [Quarter mark]
--         FROM MARKJOIN STUDENT on MARK.STUDENT_ID = STUDENT.STUDENT_IDWHERE MARK.MARK_DATE BETWEEN '2021-09-01' AND '2022-05-31'GROUP BY    STUDENT.NAME, YEAR(MARK.MARK_DATE),    CASE        WHEN MONTH(MARK.MARK_DATE) IN (9, 10, 11) THEN 'Sep-Nov'        WHEN MONTH(MARK.MARK_DATE) IN (12, 1, 2) THEN 'Dec-Feb'        ELSE 'Mar-May'    END;SELECT    STUDENT.NAME,    YEAR(MARK.MARK_DATE) AS Year,    AVG(MARK.MARK) AS [Year mark]
--                                                                                                                                                                                                                                                                                                                                                    FROM MARKJOIN STUDENT on MARK.STUDENT_ID = STUDENT.STUDENT_IDWHERE MARK.MARK_DATE BETWEEN '2021-09-01' AND '2022-05-31'GROUP BY    STUDENT.NAME, YEAR(MARK.MARK_DATE);SELECT    STUDENT.NAME,    YEAR(MARK.MARK_DATE) AS Year,    MONTH(MARK.MARK_DATE) AS Month,    CASE        WHEN MONTH(MARK.MARK_DATE) IN (9, 10, 11) THEN 'Sep-Nov'        WHEN MONTH(MARK.MARK_DATE) IN (12, 1, 2) THEN 'Dec-Feb'        ELSE 'Mar-May'    END AS Quarter,    AVG(MARK.MARK) AS AverageMark
--                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          FROM    MARK    JOIN STUDENT ON MARK.STUDENT_ID = STUDENT.STUDENT_IDWHERE    MARK.MARK_DATE BETWEEN '2021-09-01' AND '2022-05-31'GROUP BY    STUDENT.NAME,    YEAR(MARK.MARK_DATE),    MONTH(MARK.MARK_DATE),    CASE        WHEN MONTH(MARK.MARK_DATE) IN (9, 10, 11) THEN 'Sep-Nov'        WHEN MONTH(MARK.MARK_DATE) IN (12, 1, 2) THEN 'Dec-Feb'        ELSE 'Mar-May'    END;-- 2)DECLARE @AverageByFaculty float = (
-- SELECT CAST(AVG(MARK.MARK) AS float)
-- FROM MARK    JOIN STUDENT ON MARK.STUDENT_ID = STUDENT.STUDENT_ID    JOIN [GROUP] ON STUDENT.GROUP_ID = [GROUP].GROUP_ID    JOIN SPECIALITY ON [GROUP].SPECIALITY_CODE = SPECIALITY.SPECIALITY_CODE    JOIN FACULTY ON SPECIALITY.FACULTY = FACULTY.FACULTY    WHERE FACULTY.FACULTY like N'ФИТ');DECLARE @BestFacultyMark float = (
--     SELECT CAST(MAX(MARK.MARK) AS float)
--     FROM MARK    JOIN STUDENT ON MARK.STUDENT_ID = STUDENT.STUDENT_ID    JOIN [GROUP] ON STUDENT.GROUP_ID = [GROUP].GROUP_ID    JOIN SPECIALITY ON [GROUP].SPECIALITY_CODE = SPECIALITY.SPECIALITY_CODE    JOIN FACULTY ON SPECIALITY.FACULTY = FACULTY.FACULTY    WHERE FACULTY.FACULTY like N'ФИТ');SELECT    STUDENT.NAME,    AVG(MARK) AS AverageMark,    CAST(AVG(MARK) AS FLOAT) / @AverageByFaculty * 100 AS FacultyComparison,    CAST(AVG(MARK) AS FLOAT) / @BestFacultyMark * 100 AS BestMarkComparison
--                                                                                                                                                                                                                                                                                                       FROM    MARK    JOIN STUDENT ON MARK.STUDENT_ID = STUDENT.STUDENT_ID    JOIN [GROUP] ON STUDENT.GROUP_ID = [GROUP].GROUP_ID    JOIN SPECIALITY ON [GROUP].SPECIALITY_CODE = SPECIALITY.SPECIALITY_CODE    JOIN FACULTY ON SPECIALITY.FACULTY = FACULTY.FACULTYWHERE    MARK_DATE BETWEEN '2021-09-01' AND '2022-05-31'    AND    FACULTY.FACULTY = N'ФИТ'GROUP BY STUDENT.NAME;-- 3)SELECT    STUDENT.NAME,    MARK.DISCIPLINE,    AVG(MARK.MARK) AS AverageMark
--         FROM    MARK    JOIN STUDENT ON MARK.STUDENT_ID = STUDENT.STUDENT_IDWHERE    MARK.DISCIPLINE IN (
--         SELECT TOP 3 DISCIPLINE        FROM MARK        GROUP BY DISCIPLINE        ORDER BY MAX(MARK_DATE) DESC    )
-- GROUP BY    STUDENT.NAME, MARK.DISCIPLINE;select * from MARKWHERE MARK_DATE BETWEEN '06/01/2022' AND '06/25/2022';-- 4)WITH RankedMarks AS (
-- SELECT        MARK.DISCIPLINE AS Discipline,        MARK.STUDENT_ID AS Student,        COUNT(MARK.DISCIPLINE) AS Attempts
-- FROM        MARK    WHERE        MARK_DATE BETWEEN '2022-06-01' AND '2022-06-25'    GROUP BY        MARK.DISCIPLINE,        MARK.STUDENT_ID)
-- SELECT    RankedMarks.Discipline AS Discipline,    RankedMarks.Student AS Student,    RankedMarks.Attempts AS Attempts
-- FROM RankedMarks
-- WHERE    RankedMarks.Attempts = 2;


--Lab 5
