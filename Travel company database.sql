-- Poniższa tabela nie ma kluczy obcych, ponieważ zawiera informacje o klientach.
CREATE TABLE Clients (
    CustomerID INT PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Email VARCHAR(100),
    Phone VARCHAR(15)
);

-- Poniższa tabela nie ma kluczy obcych, ponieważ zawiera informacje o lokalizacjach, kierunkach podróży.
CREATE TABLE Locations (
    LocationID INT PRIMARY KEY,
    Country VARCHAR(50),
    City VARCHAR(50)
);
-- Tabela przedstawia informacje o oferowanych wycieczkach
CREATE TABLE Tours (
    TourID INT PRIMARY KEY,
    LocationID INT,
    TourName VARCHAR(100),
    Price DECIMAL(10, 2),
    Limit INT,
    FOREIGN KEY (LocationID) REFERENCES Locations(LocationID)
);
-- tabela zawierająca informacje o współpracujących hotelach
CREATE TABLE Hotels (
    HotelID INT PRIMARY KEY,
    HotelName VARCHAR(50),
    LocationID INT,
    FOREIGN KEY (LocationID) REFERENCES Locations(LocationID)
);
-- tabela prezentująca oferowane, oraz archiwalne wyjazdy wakacyjne
CREATE TABLE Vacation (
    VacationID INT PRIMARY KEY,
    VacationName VARCHAR(50),
    LocationID INT,
    HotelID INT,
    StartDate DATE,
    EndDate DATE,
    Price DECIMAL(10, 2),
    Limit INT,
    FOREIGN KEY (LocationID) REFERENCES Locations(LocationID),
    FOREIGN KEY (HotelID) REFERENCES Hotels(HotelID)
);
-- tabela z rezerwacjami wakacji, oraz wycieczek
CREATE TABLE Bookings (
    BookingID INT PRIMARY KEY,
    CustomerID INT,
    TourID INT,
    VacationID INT,
    BookingDate DATE,
    FOREIGN KEY (CustomerID) REFERENCES Clients(CustomerID),
    FOREIGN KEY (TourID) REFERENCES Tours(TourID),
    FOREIGN KEY (VacationID) REFERENCES Vacation(VacationID)
);

-- Poniższa tabela nie ma kluczy obcych, ponieważ zawiera informacje o pracownikach.
CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Phone VARCHAR(15),
    Position VARCHAR(50),
    HiringDate DATE
);
-- tabela przedstawiająca zyski pracowników ze sprzedaży wakacji i wycieczek
CREATE TABLE Commission (
    EmployeeID INT,
    TourID INT,
    VacationID INT,
    Commission DECIMAL(10, 2),
    FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID),
    FOREIGN KEY (TourID) REFERENCES Tours(TourID),
    FOREIGN KEY (VacationID) REFERENCES Vacation(VacationID),
    PRIMARY KEY (EmployeeID, TourID, VacationID)
);

-- Ograniczenie na cenę wycieczki w tabeli Tours
ALTER TABLE Tours
ADD CONSTRAINT chk_Tours_Price CHECK (Price > 0);

-- Ograniczenie na daty w tabeli Vacation
ALTER TABLE Vacation
ADD CONSTRAINT chk_Vacation_Dates CHECK (EndDate > StartDate);

-- Ograniczenie na limit osób na wycieczkę w tabeli Tours
ALTER TABLE Tours
ADD CONSTRAINT chk_Tours_Limit CHECK (Limit > 0);

-- Ograniczenie na prowizję w tabeli Commission
ALTER TABLE Commission
ADD CONSTRAINT chk_Commission_Value CHECK (Commission >= 0);

-- Widok 1. Pierwszy widok przedstawia top 10 najpopularniejszych wycieczek na podstawie liczby dokonanych rezerwacji. 
CREATE VIEW TopToursByBookings AS
SELECT TourID, TourName, NumBookings
FROM (
    SELECT t.TourID, t.TourName,
           ROW_NUMBER() OVER (ORDER BY COUNT(b.BookingID) DESC) AS RowNum,
           COUNT(b.BookingID) AS NumBookings
    FROM Tours t
    LEFT JOIN Bookings b ON t.TourID = b.TourID
    GROUP BY t.TourID, t.TourName
) AS RankedTours
WHERE RowNum <= 10; 

-- Widok 2. Drugi widok przedstawia dostępne wakacje, które nie zostały jeszcze zarezerwowane.
CREATE VIEW AvailableVacations AS
SELECT v.VacationID, v.VacationName, v.StartDate, v.EndDate, v.Price, v.Limit,
       h.HotelName, l.Country, l.City
FROM Vacation v
LEFT JOIN Bookings b ON v.VacationID = b.VacationID
INNER JOIN Hotels h ON v.HotelID = h.HotelID
INNER JOIN Locations l ON v.LocationID = l.LocationID
WHERE b.BookingID IS NULL;

-- Widok 3. Trzeci widok przedstawia podsumowanie prowizji dla każdego pracownika.
CREATE VIEW EmployeeCommissionSummary AS
SELECT e.EmployeeID, e.FirstName, e.LastName, e.Position,
       SUM(c.Commission) AS TotalCommission
FROM Employees e
LEFT JOIN Commission c ON e.EmployeeID = c.EmployeeID
GROUP BY e.EmployeeID, e.FirstName, e.LastName, e.Position;

-- Widok 4. Czwarty widok przedstawia klientów z sumowaną kwotą wydaną na wakacje.
CREATE VIEW ClientsWithMostSpent AS
SELECT CustomerID, FirstName, LastName, Email, Phone, TotalSpent
FROM (
    SELECT c.CustomerID, c.FirstName, c.LastName, c.Email, c.Phone,
           ROW_NUMBER() OVER (ORDER BY SUM(v.Price) DESC) AS RowNum,
           SUM(v.Price) AS TotalSpent
    FROM Clients c
    LEFT JOIN Bookings b ON c.CustomerID = b.CustomerID
    LEFT JOIN Vacation v ON b.VacationID = v.VacationID
    GROUP BY c.CustomerID, c.FirstName, c.LastName, c.Email, c.Phone
) AS RankedClients



-- funkcja 1 wyświetla nazwę wakacji i ich cenę wyższych od kwoty podanej w parametrze @Cena

if object_id('funkcja1','IF') is not null
drop function funkcja1
go
create function funkcja1 (@Cena money) returns table as return
(select V.VacationID, V.Price
from Vacation V
where @Cena < V.Price)
go
select * from funkcja1 (3000.00)

-- funkcja 2 wyświetla rezerwacje dokonane przed datą, która jest parametrem.

if object_id('funkcja2','IF') is not null
drop function funkcja2
go
create function funkcja2 (@Data date) returns table as return
(select B.BookingID, B.CustomerID, B.BookingDate
from Bookings B
where @Data > B.BookingDate)
go
select * from funkcja2 ('2024-02-02')


-- procedura 1: wyświetla imię oraz nazwisko klienta i nazwę zakupionej wycieczki, przy podaniu CustomerID jako parametru.
IF OBJECT_ID ('procedura1', 'P') IS NOT NULL
DROP PROC procedura1
GO
CREATE PROC procedura1 
    @KlientID int AS
BEGIN
    IF EXISTS (SELECT 1 FROM Clients C WHERE C.CustomerID = @KlientID)
    BEGIN
        SELECT C.FirstName, C.LastName, V.VacationName
        FROM Clients C 
        JOIN Bookings B ON B.CustomerID = C.CustomerID
        JOIN Vacation V ON V.VacationID = B.VacationID
        WHERE C.CustomerID = @KlientID;
    END
    ELSE
    BEGIN
    PRINT 'Brak klienta o podanym ID.';
    END
END
GO
EXEC procedura1 2;
-- procedura 2: wyświetla nazwę i cenę wycieczki o maksymalnej cenie w danej lokalizacji. Miasto jest tutaj parametrem.

create procedure procedura2
@Miasto varchar(50)
as
begin
declare @MaxPrice decimal (10,2)
	select @MaxPrice = max(T.Price)
	from Tours T  INNER JOIN Locations L ON (T.LocationID = L.LocationID)
	where @Miasto = L.City

	select T.TourName, T.Price
	from Tours T  INNER JOIN Locations L ON (T.LocationID = L.LocationID)
	where @Miasto = L.City and T.Price = @MaxPrice;
end
go
execute procedura2 @Miasto = 'Madrid'


-- wyzwalacz 1. aktualizuje dostępność wycieczki po dokonaniu rezerwacji

CREATE TRIGGER trg_UpdateTourLimit
ON Bookings
AFTER INSERT
AS
BEGIN
    UPDATE Tours
    SET Limit = Limit - 1
    FROM Tours t
    INNER JOIN inserted i ON t.TourID = i.TourID
    WHERE t.TourID = i.TourID;
END;
GO

-- wyzwalacz 2. sprawdza, czy rezerwacja nie przekracza limitu dostępnych miejsc

CREATE TRIGGER trg_CheckTourLimit
ON Bookings
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @TourID INT, @CurrentLimit INT;
    
    SELECT @TourID = i.TourID
    FROM inserted i;
    
    SELECT @CurrentLimit = Limit
    FROM Tours
    WHERE TourID = @TourID;
    
    IF @CurrentLimit > 0
    BEGIN
        INSERT INTO Bookings (BookingID, CustomerID, TourID, VacationID, BookingDate)
        SELECT BookingID, CustomerID, TourID, VacationID, BookingDate
        FROM inserted;
    END
    ELSE
    BEGIN
        PRINT 'Nie można dokonać rezerwacji, brak dostępnych miejsc na wycieczkę.';
    END
END;
GO
