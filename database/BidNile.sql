CREATE DATABASE BidNile;
GO

USE BidNile;
GO

CREATE SCHEMA Core;
GO

CREATE SCHEMA Operations;
GO

CREATE SCHEMA Catalogue;
GO

CREATE SCHEMA Sales;
GO

CREATE TABLE Core.Member
(
  Id UNIQUEIDENTIFIER NOT NULL 
    CONSTRAINT DF_Member_Id DEFAULT NEWID(),
  FullName NVARCHAR(100) NOT NULL,
  Email VARCHAR(254) NOT NULL,
  PhoneNumber VARCHAR(16) NOT NULL, -- not sure if this should be unique or not since it wasn't specified by the SRS
  NationalIdOrPassport VARCHAR(20) NOT NULL,
  BirthDate DATE NOT NULL,
  IsVerified BIT NOT NULL
    CONSTRAINT DF_Member_IsVerified DEFAULT 0,
  CreatedAt DATETIME2(3) NOT NULL
    CONSTRAINT DF_Member_CreatedAt DEFAULT SYSDATETIME(),
  ReferrerId UNIQUEIDENTIFIER NULL,
  CityId INT NOT NULL,

  CONSTRAINT PK_Member PRIMARY KEY (Id),
  CONSTRAINT UQ_Member_Email UNIQUE (Email),
  CONSTRAINT UQ_Member_NationalIdOrPassport UNIQUE (NationalIdOrPassport),
  CONSTRAINT CK_Member_BirthDate CHECK (DATEADD(Year, 18, BirthDate) <= CAST(GETDATE() AS DATE)),
  CONSTRAINT CK_Member_ReferrerId CHECK (Id <> ReferrerId)
  -- foreign key constraint: ReferrerId (Member)
  -- foreign key constraint : CityId (City)
);

CREATE TABLE Core.Employee
(
  MemberId UNIQUEIDENTIFIER NOT NULL,
  WarehouseId INT NOT NULL,

  CONSTRAINT PK_Employee PRIMARY KEY (MemberId)
  -- foreign key constraint : MemberId (Member)
  -- foreign key constraint : WarehouseId (Warehouse)
);


CREATE TABLE Core.Wallet
(
  Id INT NOT NULL IDENTITY(1, 1),
  Balance DECIMAL(12, 2) NOT NULL
    CONSTRAINT DF_Wallet_Balance DEFAULT 0,
  AmountOnHold DECIMAL(12, 2) NOT NULL
    CONSTRAINT DF_Wallet_AmountOnHold DEFAULT 0,
  Currency CHAR(3) NOT NULL
    CONSTRAINT DF_Wallet_Currency DEFAULT 'EGP',
  UpdatedAt DATETIME2(3) NULL,
  MemberId UNIQUEIDENTIFIER NOT NULL,

  CONSTRAINT PK_Wallet PRIMARY KEY (Id),
  CONSTRAINT CK_Wallet_Balance CHECK (Balance >= 0 AND Balance <= 9999999999.99),
  CONSTRAINT CK_Wallet_AmountOnHold CHECK (AmountOnHold >= 0),
  CONSTRAINT CK_Wallet_AmountOnHold_Balance CHECK (AmountOnHold <= Balance),
  CONSTRAINT UQ_Wallet_MemberId UNIQUE (MemberId)
  -- foreign key constraint: MemberId (Member)
);

CREATE TABLE Operations.City
(
  Id INT NOT NULL IDENTITY(1, 1),
  Name NVARCHAR(60) NOT NULL,
  CountryCode CHAR(2) NOT NULL,

  CONSTRAINT PK_City PRIMARY KEY (Id),
  CONSTRAINT UQ_City_Name_CountryCode UNIQUE (Name, CountryCode),
  CONSTRAINT CK_City_CountryCode CHECK (CountryCode IN ('EG', 'SA', 'AE'))
);

CREATE TABLE Operations.Warehouse
(
  Id INT NOT NULL IDENTITY(1, 1), -- primary key
  Name NVARCHAR(80) NOT NULL, -- unique
  Capacity INT NOT NULL, -- check more than zero
  Latitude FLOAT NOT NULL, -- check between -90 and 90
  Longitude FLOAT NOT NULL, -- check between -180 and 180
  CityId INT NOT NULL, -- foreign key
  ManagerId UNIQUEIDENTIFIER NULL, -- foreign key, unique
  ManagingDate DATE NULL,

  CONSTRAINT PK_Warehouse PRIMARY KEY (Id),
  CONSTRAINT UQ_Warehouse_Name UNIQUE (Name),
  CONSTRAINT CK_Warehouse_Capacity CHECK (Capacity > 0),
  CONSTRAINT CK_Warehouse_Latitude CHECK (Latitude BETWEEN -90 AND 90),
  CONSTRAINT CK_Warehouse_Longitude CHECK (Longitude BETWEEN -180 AND 180),
  CONSTRAINT UQ_Warehouse_ManagerId UNIQUE (ManagerId)

  -- foreign key constraint: ManagerId (Employee)
  -- foreign key constraint: CityId (City)
);

CREATE TABLE Catalogue.Category
(
  Code INT NOT NULL, -- primary key
  EnglishName VARCHAR(50) NOT NULL, -- unique
  ArabicName NVARCHAR(50) NULL, -- wasn't stated that it has to be unique and/or required
  Commission DECIMAL(4, 2) NOT NULL, -- check between 0 and 30
  SuperCategoryCode INT NULL, -- foreign key, check that it's not equal to code

  CONSTRAINT PK_Category PRIMARY KEY (Code),
  CONSTRAINT UQ_Category_EnglishName UNIQUE (EnglishName),
  CONSTRAINT CK_Category_Commission CHECK (Commission BETWEEN 0 AND 30),
  CONSTRAINT CK_Category_SuperCategoryCode CHECK (SuperCategoryCode <> Code)
  -- foreign key constraint: SuperCategoryCode (Category) 
);

CREATE TABLE Catalogue.Item
(
  Id INT NOT NULL IDENTITY(1, 1), -- primary key
  Title NVARCHAR(150) NOT NULL,
  Description NVARCHAR(MAX) NULL,
  ConditionScore TINYINT NOT NULL -- check between 1 and 10
    CONSTRAINT CK_Item_ConditionScore CHECK (ConditionScore BETWEEN 1 AND 10),
  Specifications NVARCHAR(MAX) NOT NULL
    CONSTRAINT CK_Item_Specifications CHECK (ISJSON(Specifications) = 1),
  ListedAt DATETIME2(3) NOT NULL -- default SYSDATETIME()
    CONSTRAINT DF_Item_ListedAt DEFAULT SYSDATETIME(),
  CategoryCode INT NOT NULL, -- foreign key
  WarehouseId INT NULL, -- foreign key
  SellerId UNIQUEIDENTIFIER NOT NULL, -- foreign key
  InspectorId UNIQUEIDENTIFIER NULL, -- foreign key

  CONSTRAINT PK_Item PRIMARY KEY (Id),
  CONSTRAINT CK_Item_SellerId_InspectorId CHECK (SellerId <> InspectorId)
  -- foreign key constraint: CategoryCode (Category)
  -- foreign key constraint: WarehouseId (Warehouse)
  -- foreign key constraint: SellerId (Member)
  -- foreign key constraint: InspectorId (Employee)
);

CREATE TABLE Catalogue.Photo
(
  ItemId INT NOT NULL, -- primary key part, foreign key
  Position TINYINT NOT NULL, -- primary key part, check between 1 and 20
  Url VARCHAR(500) NOT NULL,
  IsMain BIT NOT NULL -- default 0
    CONSTRAINT DF_Photo_IsMain DEFAULT 0,

  CONSTRAINT PK_Photo PRIMARY KEY (ItemId, Position),
  CONSTRAINT CK_Photo_Position CHECK (Position BETWEEN 1 AND 20)
  -- foreign key constraint: ItemId (Item)
);

CREATE TABLE Sales.Auction
(
  Id INT NOT NULL IDENTITY(1, 1), -- primary key
  StartingPrice DECIMAL(12, 2) NOT NULL, -- check above zero
  ReservePrice DECIMAL(12, 2) NULL, -- check not below starting price
  BidIncrement DECIMAL(12, 2) NOT NULL -- default 50.00
    CONSTRAINT DF_Auction_BidIncrement DEFAULT 50.00,
  StartDate DATETIMEOFFSET(3) NOT NULL,
  EndDate DATETIMEOFFSET(3) NOT NULL,
  Status VARCHAR(20) NOT NULL -- default
    CONSTRAINT DF_Auction_Status DEFAULT 'Draft',
  ItemId INT NOT NULL, -- foreign key

  CONSTRAINT PK_Auction PRIMARY KEY (Id),
  CONSTRAINT CK_Auction_StartingPrice CHECK (StartingPrice > 0),
  CONSTRAINT CK_Auction_ReservePrice CHECK (ReservePrice IS NULL OR ReservePrice >= StartingPrice),
  CONSTRAINT CK_Auction_Status CHECK (Status IN ('Draft', 'Live', 'Ended', 'Cancelled')),
  CONSTRAINT CK_Auction_StartDate_EndDate CHECK (StartDate < EndDate),
  CONSTRAINT CK_Auction_BidIncrement CHECK (BidIncrement > 0)
  -- foreign key: ItemId (Item)
);

CREATE TABLE Sales.Bid
(
  Id BIGINT NOT NULL IDENTITY(1, 1), -- primary key
  Amount DECIMAL(12, 2) NOT NULL, -- check above zero
  CreatedAt DATETIME2(3) NOT NULL -- defualt
    CONSTRAINT DF_Bid_CreatedAt DEFAULT SYSDATETIME(),
  DeviceIPAddress VARCHAR(45) NOT NULL,
  AuctionId INT NOT NULL, -- foreign key
  BidderId UNIQUEIDENTIFIER NOT NULL, -- foreign key

  CONSTRAINT PK_Bid PRIMARY KEY (Id),
  CONSTRAINT CK_Bid_Amount CHECK (Amount > 0),
  CONSTRAINT UQ_Bid_Amount_AuctionId UNIQUE (Amount, AuctionId)
  -- foreign key: AuctionId (Auction)
  -- foreign key: BidderId (Member)
);

CREATE TABLE Sales.AuctionFollower
(
  AuctionId INT NOT NULL, -- primary key part, foreign key
  FollowerId UNIQUEIDENTIFIER NOT NULL, -- primary key part, foreign key
  FollowingDate DATETIME2(3) NOT NULL
    CONSTRAINT DF_AuctionFollower_FollowingDate DEFAULT SYSDATETIME(),

  CONSTRAINT PK_AuctionFollower PRIMARY KEY (AuctionId, FollowerId)
  -- foreign key: AuctionId (Auction)
  -- foreign key: FollowerId (Member)
);
GO


-- ============================================================
-- Task 3 — ALTER: Business Changes
-- ============================================================

-- 3.1
ALTER TABLE Core.Member
ADD CONSTRAINT FK_Member_Member FOREIGN KEY (ReferrerId) REFERENCES Core.Member (Id),
    CONSTRAINT FK_Member_City FOREIGN KEY (CityId) REFERENCES Operations.City (Id);

ALTER TABLE Core.Employee
ADD CONSTRAINT FK_Employee_Member FOREIGN KEY (MemberId) REFERENCES Core.Member (Id),
    CONSTRAINT FK_Employee_Warehouse FOREIGN KEY (WarehouseId) REFERENCES Operations.Warehouse (Id);

ALTER TABLE Core.Wallet
ADD CONSTRAINT FK_Wallet_Member FOREIGN KEY (MemberId) REFERENCES Core.Member (Id);

ALTER TABLE Operations.Warehouse
ADD CONSTRAINT FK_Warehouse_City FOREIGN KEY (CityId) REFERENCES Operations.City (Id),
    CONSTRAINT FK_Warehouse_Employee FOREIGN KEY (ManagerId) REFERENCES Core.Employee (MemberId);

ALTER TABLE Catalogue.Category
ADD CONSTRAINT FK_Category_Category FOREIGN KEY (SuperCategoryCode) REFERENCES Catalogue.Category (Code);

ALTER TABLE Catalogue.Item
ADD CONSTRAINT FK_Item_Category FOREIGN KEY (CategoryCode) REFERENCES Catalogue.Category (Code),
    CONSTRAINT FK_Item_Warehouse FOREIGN KEY (WarehouseId) REFERENCES Operations.Warehouse (Id),
    CONSTRAINT FK_Item_Member FOREIGN KEY (SellerId) REFERENCES Core.Member (Id),
    CONSTRAINT FK_Item_Employee FOREIGN KEY (InspectorId) REFERENCES Core.Employee (MemberId);

ALTER TABLE Catalogue.Photo
ADD CONSTRAINT FK_Photo_Item FOREIGN KEY (ItemId) REFERENCES Catalogue.Item (Id) ON DELETE CASCADE;

ALTER TABLE Sales.Auction
ADD CONSTRAINT FK_Auction_Item FOREIGN KEY (ItemId) REFERENCES Catalogue.Item (Id);

ALTER TABLE Sales.Bid
ADD CONSTRAINT FK_Bid_Auction FOREIGN KEY (AuctionId) REFERENCES Sales.Auction (Id),
    CONSTRAINT FK_Bid_Member FOREIGN KEY (BidderId) REFERENCES Core.Member (Id);

ALTER TABLE Sales.AuctionFollower
ADD CONSTRAINT FK_AuctionFollower_Auction FOREIGN KEY (AuctionId) REFERENCES Sales.Auction (Id),
    CONSTRAINT FK_AuctionFollower_Member FOREIGN KEY (FollowerId) REFERENCES Core.Member (Id);
GO

-- 3.2
ALTER TABLE Core.Member
ADD AppLanguage CHAR(2) NOT NULL
        CONSTRAINT DF_Member_AppLanguage DEFAULT 'ar' WITH VALUES,
    CONSTRAINT CK_Member_AppLanguage CHECK (AppLanguage IN ('ar', 'en'));
GO

-- 3.3
ALTER TABLE Catalogue.Item
ADD IsFeatured BIT NOT NULL
    CONSTRAINT DF_Item_IsFeatured DEFAULT 0 WITH VALUES;
GO

-- 3.4
EXEC sp_rename 'Sales.Bid.DeviceIPAddress', 'DeviceIp', 'COLUMN';

-- sp_rename blocks renaming a column with an enforced CHECK constraint (Msg 15336),
-- so drop CK_Warehouse_Capacity, rename the column, and re-add the CHECK constraint.
ALTER TABLE Operations.Warehouse
DROP CONSTRAINT CK_Warehouse_Capacity;

EXEC sp_rename 'Operations.Warehouse.Capacity', 'MaxItems', 'COLUMN';
GO

ALTER TABLE Operations.Warehouse
ADD CONSTRAINT CK_Warehouse_MaxItems CHECK (MaxItems > 0);
GO

-- 3.5
ALTER TABLE Core.Member
ALTER COLUMN FullName NVARCHAR(150) NOT NULL;
GO

-- 3.6
-- Altering MaxItems directly fails because CK_Warehouse_MaxItems depends on it.
-- Drop the CHECK constraint first, change the column to SMALLINT (max 32,767), then re-add the CHECK.
ALTER TABLE Operations.Warehouse
DROP CONSTRAINT CK_Warehouse_MaxItems;

ALTER TABLE Operations.Warehouse
ALTER COLUMN MaxItems SMALLINT NOT NULL;

ALTER TABLE Operations.Warehouse
ADD CONSTRAINT CK_Warehouse_MaxItems CHECK (MaxItems > 0);
GO

-- 3.7
ALTER TABLE Catalogue.Category
DROP CONSTRAINT CK_Category_Commission;

ALTER TABLE Catalogue.Category
ADD CONSTRAINT CK_Category_Commission CHECK (Commission BETWEEN 0 AND 25);
GO

-- 3.8
ALTER TABLE Sales.Auction
DROP CONSTRAINT CK_Auction_Status;

ALTER TABLE Sales.Auction
ADD CONSTRAINT CK_Auction_Status CHECK (Status IN ('PendingReview', 'Draft', 'Live', 'Ended', 'Cancelled'));

ALTER TABLE Sales.Auction
DROP CONSTRAINT DF_Auction_Status;

ALTER TABLE Sales.Auction
ADD CONSTRAINT DF_Auction_Status DEFAULT 'PendingReview' FOR Status;
GO

-- 3.9
ALTER TABLE Sales.Auction
ADD BuyNowPrice DECIMAL(12, 2) NULL;
GO

-- Use WITH CHECK: BuyNowPrice is a newly added nullable column, so every existing row has NULL
-- (which passes the CHECK condition). WITH CHECK validates existing rows and marks the constraint
-- as trusted (is_not_trusted = 0) so the SQL Server query optimizer can rely on it.
-- WITH NOCHECK would skip validation and leave the constraint untrusted for no benefit here.
ALTER TABLE Sales.Auction
WITH CHECK ADD CONSTRAINT CK_Auction_BuyNowPrice
    CHECK (BuyNowPrice IS NULL OR BuyNowPrice > StartingPrice);
GO

-- 3.10
ALTER TABLE Core.Member
ADD CONSTRAINT UQ_Member_PhoneNumber UNIQUE (PhoneNumber);
GO

-- 3.11
-- Dropping IsVerified directly fails because DF_Member_IsVerified is bound to it.
-- Add VerifiedAt, drop the default constraint first, then drop IsVerified.
ALTER TABLE Core.Member
ADD VerifiedAt DATETIME2(3) NULL;

ALTER TABLE Core.Member
DROP CONSTRAINT DF_Member_IsVerified;

ALTER TABLE Core.Member
DROP COLUMN IsVerified;
GO

-- 3.12
CREATE SCHEMA Marketing;
GO

ALTER SCHEMA Marketing
TRANSFER Sales.AuctionFollower;
GO
