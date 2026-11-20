# BidNile — Design & Implementation Notes

## 1. The 4 Schemas, Their Tables, and Why

1. **`Core`** — `Member`, `Employee`, `Wallet`
   - Owns identity, staff roles, and each member's personal financial wallet. Keeping user accounts, employee specialization, and wallets together groups all core user-facing entities in one domain.
2. **`Operations`** — `City`, `Warehouse`
   - Owns geographic coverage and physical warehouse logistics. Separates physical infrastructure and locations from user accounts and product listings.
3. **`Catalogue`** — `Category`, `Item`, `Photo`
   - Owns product taxonomy, listed items, and item media. Groups everything related to what is being listed and inspected before an auction starts.
4. **`Sales`** — `Auction`, `Bid`, `AuctionFollower` *(transferred to `Marketing` in Task 3.12)*
   - Owns the live auction engine, bidding records, and auction engagement. Separating `Sales` from `Catalogue` cleanly reflects that a single unsold item can go through multiple auctions over time.

---

## 2. Relationship Types & How They Were Mapped

- **1:1 (One-to-One)**
  - `Core.Member` ↔ `Core.Wallet`: Mapped with `Wallet.MemberId` as a `NOT NULL` Foreign Key + `UNIQUE` constraint (`UQ_Wallet_MemberId`), guaranteeing every member has at most one wallet and no wallet is shared.
  - `Core.Member` ↔ `Core.Employee`: Mapped using a shared Primary Key (`Employee.MemberId` is both `PK_Employee` and `FK_Employee_Member`), ensuring only valid members can be employees and that `Item.SellerId` and `Item.InspectorId` share the same GUID domain.
  - `Core.Employee` ↔ `Operations.Warehouse` (manages): Mapped by placing `ManagerId` (`UNIQUE`, `NULL`) and `ManagingDate` on `Operations.Warehouse` (the total-participation side) with `UQ_Warehouse_ManagerId` so one employee manages at most one warehouse.
- **1:N (One-to-Many)**
  - `Operations.City` → `Core.Member` (`Member.CityId`), `Operations.City` → `Operations.Warehouse` (`Warehouse.CityId`), `Catalogue.Category` → `Catalogue.Item` (`Item.CategoryCode`), `Operations.Warehouse` → `Catalogue.Item` (`Item.WarehouseId`), `Core.Member` → `Catalogue.Item` (`Item.SellerId`), `Core.Employee` → `Catalogue.Item` (`Item.InspectorId`), `Catalogue.Item` → `Sales.Auction` (`Auction.ItemId`), `Sales.Auction` → `Sales.Bid` (`Bid.AuctionId`), `Core.Member` → `Sales.Bid` (`Bid.BidderId`), `Operations.Warehouse` → `Core.Employee` (`Employee.WarehouseId`).
  - Each mapped by placing the `1`-side Primary Key as a Foreign Key column on the `N`-side table.
- **M:N (Many-to-Many)**
  - `Core.Member` ↔ `Sales.Auction` (follows): Mapped into the junction table `Sales.AuctionFollower` (moved to `Marketing.AuctionFollower` in 3.12) with a composite Primary Key `(AuctionId, FollowerId)` and the relationship attribute `FollowingDate`.
- **Recursive (Unary / Self-Referencing)**
  - `Core.Member` (invites): Mapped via nullable `ReferrerId` referencing `Core.Member(Id)` (`FK_Member_Member`), with `CK_Member_ReferrerId` (`Id <> ReferrerId`) preventing self-referrals.
  - `Catalogue.Category` (sits under): Mapped via nullable `SuperCategoryCode` referencing `Catalogue.Category(Code)` (`FK_Category_Category`), with `CK_Category_SuperCategoryCode` (`SuperCategoryCode <> Code`). Top-level categories store `NULL`.
- **Circular**
  - `Core.Employee` ↔ `Operations.Warehouse`: `Employee.WarehouseId` references `Warehouse(Id)` (works in), while `Warehouse.ManagerId` references `Employee(MemberId)` (manages).
  - Mapped by creating both tables first without Foreign Keys, adding both FKs via `ALTER TABLE` in Task 3.1, and making `Warehouse.ManagerId` nullable so a warehouse can be inserted before assigning its manager.
- **Weak Entity**
  - `Catalogue.Photo` (owned by `Catalogue.Item`): Mapped with a composite Primary Key `(ItemId, Position)` combining the owner's PK and the partial key (`Position` 1–20), plus `FK_Photo_Item` with `ON DELETE CASCADE` so photos disappear automatically if their item is deleted.

---

## 3. Data Type Choices

- **Why `UNIQUEIDENTIFIER` (GUID) for `Member`?**
  - The mobile app generates member IDs offline on the user's phone before the request reaches the server. A sequential `IDENTITY` integer cannot be safely generated across distributed mobile clients without collisions, whereas a 128-bit GUID is globally unique across devices (with `DEFAULT NEWID()` as a server-side fallback).
- **Why `BIGINT` for `Bid`?**
  - Standard `INT` maxes out at ~2.14 billion (`2,147,483,647`). BidNile expects hundreds of millions of bids per year and will cross 2.1 billion within a few years; `BIGINT` supports up to ~9.22 quintillion, preventing identity overflow.
- **Why `FLOAT` for GPS but `DECIMAL` for money?**
  - `FLOAT` is an IEEE 754 binary floating-point type designed for approximate scientific/geographic measurements with many decimals (GPS coordinates). Money requires **exact** base-10 arithmetic with zero binary rounding errors (e.g., avoiding `0.1 + 0.2 = 0.30000000000000004`), so `DECIMAL(12, 2)` is mandatory for balances, holds, prices, and bids.
- **Why `DATETIMEOFFSET` for auctions?**
  - Members bid across Cairo (`+02:00`), Riyadh (`+03:00`), and Dubai (`+04:00`). `DATETIMEOFFSET` stores both the local wall-clock time and its explicit UTC offset (e.g., `2026-12-05 18:30:00 +04:00`), allowing unambiguous timeline comparisons (`StartDate < EndDate`) and accurate countdowns across time zones.

---

## 4. Why Can't the Circular Relationship Be Created Inside `CREATE TABLE`?

In a circular relationship (`Core.Employee` references `Operations.Warehouse`, and `Operations.Warehouse` references `Core.Employee`), whichever table you try to `CREATE TABLE` first cannot declare an inline `FOREIGN KEY` pointing to the second table because the second table **does not exist yet** in the database catalog (SQL Server raises an invalid object name error). Creating both tables first with their FK columns and adding the `FOREIGN KEY` constraints afterward with `ALTER TABLE ... ADD CONSTRAINT` (Task 3.1) resolves the creation-order deadlock.

---

## 5. Table Population Order (and Why)

Because all Foreign Key constraints are active before loading data in Task 4, parent rows must exist before any child row references them:

1. **`Operations.City`** — No foreign keys.
2. **`Catalogue.Category`** — Self-referencing only: insert top-level categories first (`SuperCategoryCode = NULL`), then subcategories referencing them.
3. **`Core.Member`** — References `Operations.City` and self (`ReferrerId`): insert initial members with `ReferrerId = NULL` first, then invited members referencing existing members.
4. **`Core.Wallet`** — References `Core.Member`.
5. **`Operations.Warehouse` (Step A)** — References `Operations.City` and `Core.Employee`: insert warehouses with `ManagerId = NULL` and `ManagingDate = NULL` first to break the circular dependency.
6. **`Core.Employee`** — References `Core.Member` and `Operations.Warehouse` (now both exist).
7. **`Operations.Warehouse` (Step B — Update)** — Update each warehouse's `ManagerId` and `ManagingDate` to point to its assigned `Core.Employee`.
8. **`Catalogue.Item`** — References `Catalogue.Category`, `Operations.Warehouse`, `Core.Member` (seller), and `Core.Employee` (inspector, distinct from seller).
9. **`Catalogue.Photo`** — References `Catalogue.Item`.
10. **`Sales.Auction`** — References `Catalogue.Item`.
11. **`Sales.Bid`** — References `Sales.Auction` and `Core.Member`.
12. **`Marketing.AuctionFollower`** — References `Sales.Auction` and `Core.Member`.

---

## 6. The Errors in Tasks 3.6 and 3.11, and How They Were Fixed

- **Task 3.6 (`ALTER COLUMN MaxItems SMALLINT NOT NULL`):**
  - **Error:** SQL Server blocks `ALTER COLUMN` on `Operations.Warehouse.MaxItems` with *`The object 'CK_Warehouse_MaxItems' is dependent on column 'MaxItems'. ALTER TABLE ALTER COLUMN MaxItems failed because one or more objects access this column.`* (Similarly in Task 3.4, `sp_rename` failed with `Msg 15336` until `CK_Warehouse_Capacity` was dropped and re-added as `CK_Warehouse_MaxItems`.)
  - **Fix:** Drop the dependent check constraint (`DROP CONSTRAINT CK_Warehouse_MaxItems`), run `ALTER COLUMN MaxItems SMALLINT NOT NULL`, and re-create the check constraint (`ADD CONSTRAINT CK_Warehouse_MaxItems CHECK (MaxItems > 0)`).
- **Task 3.11 (`DROP COLUMN IsVerified`):**
  - **Error:** SQL Server blocks `DROP COLUMN` on `Core.Member.IsVerified` with *`The object 'DF_Member_IsVerified' is dependent on column 'IsVerified'. ALTER TABLE DROP COLUMN IsVerified failed because one or more objects access this column.`*
  - **Fix:** Add `VerifiedAt DATETIME2(3) NULL`, explicitly drop the attached default constraint (`DROP CONSTRAINT DF_Member_IsVerified`), and then run `DROP COLUMN IsVerified`.

---

## 7. Hand Trace from Task 5 (`ProductExceptSelf([1, 2, 3, 4])`)

Input: `nums = [1, 2, 3, 4]`

- `prefix[i]` = product of all elements strictly to the **left** of index `i` (`prefix[0] = 1`).
- `suffix[i]` = product of all elements strictly to the **right** of index `i` (`suffix[3] = 1`).
- `result[i] = prefix[i] * suffix[i]`.

| Index `i` | `nums[i]` | `prefix[i]` | `suffix[i]` | `result[i] = prefix[i] * suffix[i]` |
| :---: | :---: | :--- | :--- | :---: |
| `0` | `1` | `1` | `2 * 3 * 4 = 24` | `1 * 24 = 24` |
| `1` | `2` | `1` | `3 * 4 = 12` | `1 * 12 = 12` |
| `2` | `3` | `1 * 2 = 2` | `4` | `2 * 4 = 8` |
| `3` | `4` | `1 * 2 * 3 = 6` | `1` | `6 * 1 = 6` |

Output: `[24, 12, 8, 6]`
