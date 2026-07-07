USE AdventureWorks2022
GO


/* Analiza Dostaw */
SELECT * FROM Purchasing.ProductVendor;
SELECT * FROM Purchasing.Vendor;
SELECT * FROM Purchasing.PurchaseOrderDetail;
SELECT * FROM Purchasing.PurchaseOrderHeader;

-- Dostawcy z najkrótszym czasem dostawy. Można znaleźć najszybszych dostawców.
SELECT
	v.Name,
	AVG(pv.AverageLeadTime) AS AvgLeadTime -- średni czas realizacji
FROM Purchasing.ProductVendor pv
JOIN Purchasing.Vendor v ON pv.BusinessEntityID = v.BusinessEntityID
GROUP BY v.Name
ORDER BY AvgLeadTime;

-- Najtańsi dostawcy
SELECT
    v.Name,
    AVG(pv.StandardPrice) AS AvgPrice
FROM Purchasing.ProductVendor pv
JOIN Purchasing.Vendor v
    ON pv.BusinessEntityID = v.BusinessEntityID
GROUP BY v.Name
ORDER BY AvgPrice;

-- Ile zamówień złożono u każdego dostawcy, pokazuje z którymi dostawcami firma współpracuje najczęściej. 
SELECT
	v.Name AS Nazwa_dostawcy,
	COUNT(*) AS NumberOfOrders
FROM Purchasing.Vendor v
JOIN Purchasing.PurchaseOrderHeader poh ON v.BusinessEntityID = poh.VendorID
GROUP BY v.Name
ORDER BY NumberOfOrders DESC;

-- Wartość zakupów u dostawców. Ile pieniędzy wydaliśmy u każdego dostawcy.
SELECT 
	v.Name,
	SUM(poh.TotalDue) AS TotalPurchases
FROM Purchasing.Vendor v
JOIN Purchasing.PurchaseOrderHeader poh ON v.BusinessEntityID = poh.VendorID
GROUP BY v.Name
ORDER BY TotalPurchases DESC;

-- Ilu różnych produktów dostarcza dostawca, można ocenić czy dostawca jest wyspecjalizowany, czy oferuje szeroki asortyment.
SELECT
    v.Name,
    COUNT(DISTINCT pv.ProductID) AS Unikalne_produkty
FROM Purchasing.ProductVendor pv
JOIN Purchasing.Vendor v
    ON pv.BusinessEntityID = v.BusinessEntityID
GROUP BY v.Name
ORDER BY Unikalne_produkty DESC;

-- Najdroższe zamówienia zakupu. Pokazuje największe zakupy firmy.
SELECT TOP 10
	poh.PurchaseOrderID,
	v.Name,
	poh.OrderDate,
	poh.TotalDue
FROM Purchasing.PurchaseOrderHeader poh
JOIN Purchasing.Vendor v ON poh.VendorID = v.BusinessEntityID
ORDER BY TotalDue DESC;

-- Dostawcy z największą liczbą dostarczonych sztuk.
SELECT
	v.Name AS Dostawca,
	SUM(pod.OrderQty) AS TotalItemsDelivered
FROM Purchasing.PurchaseOrderHeader poh
JOIN Purchasing.PurchaseOrderDetail pod ON poh.PurchaseOrderID = pod.PurchaseOrderID
JOIN Purchasing.Vendor v ON poh.VendorID = v.BusinessEntityID
GROUP BY v.Name
ORDER BY TotalItemsDelivered DESC;

-- Dostawcy z największą liczbą odrzuconych produktów. 
SELECT
	v.Name AS Dostawca,
	SUM(pod.ReceivedQty) AS Odrzucone_produkty
FROM Purchasing.PurchaseOrderHeader poh
JOIN Purchasing.PurchaseOrderDetail pod ON poh.PurchaseOrderID = pod.PurchaseOrderDetailID
JOIN Purchasing.Vendor v ON poh.VendorID = v.BusinessEntityID
GROUP BY v.Name
HAVING SUM(pod.ReceivedQty) > 0
ORDER BY Odrzucone_produkty DESC;

/* Analiza Produktów i Magazynu */
SELECT * FROM Production.Product;
SELECT * FROM Production.ProductCategory;
SELECT * FROM Production.ProductInventory;
SELECT * FROM Production.Location;

-- Aktualny stan magazynowy każdego produktu
SELECT 
	p.ProductID,
	p.Name,
	SUM(pin.Quantity) AS TotalQuantity
FROM Production.Product p
JOIN Production.ProductInventory pin ON p.ProductID = pin.ProductID
GROUP BY p.ProductID, p.Name
ORDER BY TotalQuantity DESC;

-- W jakim magazynie znajduje się produkt? Pokazuje gdzie dokładnie znajduje się produkt.
SELECT
	p.Name AS Name_product,
	l.Name AS Warehouse_location,
	pi.Shelf,
	pi.Quantity,
	pi.Bin
FROM Production.Product p
JOIN Production.ProductInventory pi ON p.ProductID = pi.ProductID
JOIN Production.Location l ON pi.LocationID = l.LocationID
ORDER BY Name_product;

-- Produkty o niskim stanie magazynowym. Znaleźć produkty, które powinny zostać ponownie zamówione.
SELECT p.Name, SUM(pi.Quantity) AS Stock
FROM Production.Product p
JOIN Production.ProductInventory pi ON p.ProductID = pi.ProductID
GROUP BY p.Name
HAVING SUM(pi.Quantity) < 100;

-- Wartość zapasów magazynowych
SELECT
		p.Name, 
		SUM(pi.Quantity) AS Quantity,
		p.StandardCost,
		SUM(pi.Quantity * p.StandardCost) AS InventoryValue
FROM Production.Product p
JOIN Production.ProductInventory pi ON p.ProductID = pi.ProductID
GROUP BY p.Name, p.StandardCost
ORDER BY InventoryValue DESC; 

-- Średni koszt produktów w każdej kategorii
SELECT
	pc.Name AS Category,
	AVG(p.StandardCost) AS AvgCost
FROM Production.Product p
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
GROUP BY pc.Name;

-- Klasyfikacja produktów, użycie CASE
SELECT
	Name,
	ListPrice,
	CASE 
		WHEN ListPrice < 500 THEN 'Cheap'
		WHEN ListPrice BETWEEN 500 AND 1500 THEN 'Medium'
		ELSE 'Expensive'
	END AS PriceCategory
FROM Production.Product;

-- Top 5 produktów w każdej kategorii. Funkcja okna. Z każdej kategori wybiera po 5 rekordów i nadaje im 'rn'(kolejnosc)
WITH ProductSales AS
(
SELECT 
	pc.Name AS Category,
	p.Name,
	SUM(sod.LineTotal) AS Revenue,
	ROW_NUMBER() OVER ( PARTITION BY pc.Name ORDER BY SUM(sod.LineTotal) DESC ) AS rn

FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
GROUP BY
	pc.Name,
	p.Name
)
SELECT * 
FROM ProductSales
WHERE rn<=5;

-- Stan magazynowy według lokalizacji, pokazanie, które lokalizacje są najbardziej zapełnione.
SELECT 
	l.Name AS Warehouse,
	SUM(pi.Quantity) AS TotalProducts
FROM Production.ProductInventory pi
JOIN Production.Location l ON pi.LocationID = l.LocationID
GROUP BY l.Name
ORDER BY TotalProducts DESC;

-- Liczba lokalizacji, w których znajduje się produkt; pokazanie, czy produkt jest rozproszony po magazynie. 
SELECT
	p.Name,
	COUNT(DISTINCT pi.LocationID) AS NumberOfLocations,
	SUM(pi.Quantity) AS TotalQuantity
FROM Production.Product p
JOIN Production.ProductInventory pi ON p.ProductID = pi.ProductID
GROUP BY p.Name
ORDER BY NumberOfLocations DESC;

-- Produkty przechowywane w więcej niż jednej lokalizacji. To pozwala znaleźć produkty rozłożone na kilka stref magazynowych.  
SELECT
    p.Name,
    COUNT(DISTINCT pi.LocationID) AS Locations
FROM Production.Product p
JOIN Production.ProductInventory pi
    ON p.ProductID = pi.ProductID
GROUP BY p.Name
HAVING COUNT(DISTINCT pi.LocationID) > 1;

-- Ile różnych produktów znajduje się w każdej lokalizacji. To pokazuje różnorodność asortymentu w poszczególnych lokalizacjach.
SELECT 
	l.Name,
	COUNT(DISTINCT pi.ProductID) AS ProductStored
FROM Production.ProductInventory pi
JOIN Production.Location l ON pi.LocationID = l.LocationID
GROUP BY l.Name
ORDER BY ProductStored;

-- Produkty z największą liczbą sztuk w jednej lokalizacji. To pokazuje rekordy z największą liczbą sztuk w pojedynczej lokalizacji.
SELECT TOP 10
	p.Name,
	l.Name AS Location,
	pi.Quantity
FROM Production.ProductInventory pi
JOIN Production.Product p ON pi.ProductID = p.ProductID
JOIN Production.Location l ON pi.LocationID = l.LocationID
ORDER BY pi.Quantity DESC;

-- Przykładowe zapytania: Produkty + Magazyn + Dostawy

-- Jakie produkty dostarcza każdy dostawca
SELECT
	v.Name AS Ventor_dostawca,
	p.Name AS Product
FROM Purchasing.ProductVendor pv
JOIN Purchasing.Vendor v ON pv.BusinessEntityID = v.BusinessEntityID
JOIN Production.Product p ON pv.ProductID = p.ProductID
ORDER BY v.Name, p.Name 

--ilosc zamówienia dla każdego dostawcy, czyli ile dostawca przwiózł konkretnego produktu
SELECT
	v.Name AS Ventor_dostawca,
	p.Name AS Product,
	SUM(pod.OrderQty) AS całkowita_wartosc_przywieziona, -- TotalDelivered
	COUNT(DISTINCT poh.PurchaseOrderID) AS Ilosc_dostaw  -- dla danego produtku - ile dostaw
FROM Purchasing.Vendor v
JOIN Purchasing.PurchaseOrderHeader poh ON v.BusinessEntityID = poh.VendorID
JOIN Purchasing.PurchaseOrderDetail pod ON poh.PurchaseOrderID = pod.PurchaseOrderID
JOIN Production.Product p ON pod.ProductID = p.ProductID
GROUP BY v.Name, p.Name
ORDER BY v.Name, całkowita_wartosc_przywieziona DESC;

-- Jakie produkty znalazły się w konkretnym zamówieniu. 
SELECT
	poh.PurchaseOrderID,
    p.Name,
    pod.OrderQty,
    pod.UnitPrice,
    pod.LineTotal
FROM Purchasing.PurchaseOrderHeader poh
JOIN Purchasing.PurchaseOrderDetail pod ON poh.PurchaseOrderID = pod.PurchaseOrderID
JOIN Production.Product p ON pod.ProductID = p.ProductID
WHERE poh.PurchaseOrderID = 2;

-- Najczęściej kupowane produkty od dostawców, które produkty firma kupuje najczęściej.
SELECT
	p.Name AS Product,
	SUM(pod.OrderQty) AS zakupiony
FROM Purchasing.PurchaseOrderDetail pod
JOIN Production.Product p ON pod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY zakupiony DESC;

-- Średnia cena zakupu produktu. Można analizować: koszty zakupów, porównywać z ceną sprzedaży.
SELECT
    p.Name,
    AVG(pod.UnitPrice) AS AvgPurchasePrice
FROM Purchasing.PurchaseOrderDetail pod
JOIN Production.Product p ON pod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY AvgPurchasePrice DESC;

-- Wartość zakupów każdego produktu. Analiza nie ilości sztuk, ale ile pieniędzy wydano na zakup danego produktu. Może się okazać, że produkt jest kupowany rzadko, ale jest bardzo drogi.
SELECT
	p.Name,
	SUM(pod.LineTotal) AS PurchaseValue -- wartosc zakupu
FROM Purchasing.PurchaseOrderDetail pod
JOIN Production.Product p ON pod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY PurchaseValue;

-- Ile produktów faktycznie przyjęto do magazynu i odrzucono. Ile sztuk rzeczywiście trafiło do magazynu.
SELECT
	p.Name,
	SUM(pod.StockedQty) AS Przyjeto,
	SUM(pod.RejectedQty) AS Odrzucono
FROM Purchasing.PurchaseOrderDetail pod
JOIN Production.Product p ON pod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY Przyjeto DESC; 

-- Skuteczność realizacji dostaw. 100% gdy wszystko zamówione zostało przyjęte do magazynu.
-- 90% gdy część zamówienia nie została dostarczona lub została odrzucona.
SELECT
	p.Name,
	SUM(pod.OrderQty) AS Ordered,
	SUM(pod.StockedQty) AS Stocked,
	ROUND(
		SUM(pod.StockedQty) * 100.0 /
		SUM(pod.OrderQty),
		2) AS DeliveryEfficiency
FROM Purchasing.PurchaseOrderDetail pod
JOIN Production.Product p ON pod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY DeliveryEfficiency;

-- Produkty zamawiane najczęściej. To różni się od sumy zamówionych sztuk.
SELECT
    p.Name,
    COUNT(*) AS NumberOfOrders
FROM Purchasing.PurchaseOrderDetail pod
JOIN Production.Product p
    ON pod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY NumberOfOrders DESC;

-- Raport kompleksowy: zamówione, przyjęte, odrzucone, wartość całkowita
SELECT
    p.Name,
    SUM(pod.OrderQty) AS Ordered,
    SUM(pod.StockedQty) AS Stocked,
    SUM(pod.RejectedQty) AS Rejected,
    SUM(pod.LineTotal) AS PurchaseValue
FROM Purchasing.PurchaseOrderDetail pod
JOIN Production.Product p
    ON pod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY PurchaseValue DESC;

-- Połączenie: dostawca + produkt + lokalizacja.
SELECT
    v.Name AS Vendor,
    p.Name AS Product,
    l.Name AS Location,
    SUM(pi.Quantity) AS Stock
FROM Purchasing.PurchaseOrderHeader poh
JOIN Purchasing.PurchaseOrderDetail pod ON poh.PurchaseOrderID = pod.PurchaseOrderID
JOIN Purchasing.Vendor v ON poh.VendorID = v.BusinessEntityID
JOIN Production.Product p ON pod.ProductID = p.ProductID
JOIN Production.ProductInventory pi ON p.ProductID = pi.ProductID
JOIN Production.Location l ON pi.LocationID = l.LocationID
GROUP BY v.Name, p.Name, l.Name
ORDER BY v.Name, p.Name;

-- Dostawca + produkt + wartość zapasu. Jaką wartość mają obecne zapasy produktów pochodzących od poszczególnych dostawców?
SELECT
    v.Name AS Vendor,
    p.Name AS Product,
    SUM(pi.Quantity) AS Stock,
    p.StandardCost,
    SUM(pi.Quantity * p.StandardCost) AS InventoryValue
FROM Purchasing.PurchaseOrderHeader poh
JOIN Purchasing.PurchaseOrderDetail pod ON poh.PurchaseOrderID = pod.PurchaseOrderID
JOIN Purchasing.Vendor v ON poh.VendorID = v.BusinessEntityID
JOIN Production.Product p ON pod.ProductID = p.ProductID
JOIN Production.ProductInventory pi ON p.ProductID = pi.ProductID
GROUP BY
    v.Name,
    p.Name,
    p.StandardCost
ORDER BY InventoryValue DESC;

-- Dostawca → produkt → wartość zapasu. Jaką wartość mają obecne zapasy produktów pochodzących od poszczególnych dostawców?
SELECT
    v.Name AS Vendor,
    p.Name AS Product,
    SUM(pi.Quantity) AS Stock,
    p.StandardCost,
    SUM(pi.Quantity * p.StandardCost) AS InventoryValue
FROM Purchasing.PurchaseOrderHeader poh
JOIN Purchasing.PurchaseOrderDetail pod ON poh.PurchaseOrderID = pod.PurchaseOrderID
JOIN Purchasing.Vendor v ON poh.VendorID = v.BusinessEntityID
JOIN Production.Product p ON pod.ProductID = p.ProductID
JOIN Production.ProductInventory pi ON p.ProductID = pi.ProductID
WHERE p.Name = 'Front Brakes'  -- konkretny produkt
GROUP BY
   v.Name,
   p.Name,
   p.StandardCost; 


/* Analiza Produkcji  */
SELECT * FROM Production.WorkOrder;
SELECT * FROM Production.WorkOrderRouting;
SELECT * FROM Production.BillOfMaterials;
SELECT * FROM Production.TransactionHistory;

-- Z jakich komponentów składa się każdy produkt?
SELECT 
	pa.Name AS Product, -- nazwa produktu
	pc.Name AS Component,	-- część z jakiego składa sie produkt
	bom.PerAssemblyQty -- ilosc
FROM Production.BillOfMaterials bom
JOIN Production.Product pa ON bom.ProductAssemblyID = pa.ProductID
JOIN Production.Product pc ON bom.ComponentID = pc.ProductID
ORDER BY Product;

-- Ile komponentów posiada każdy produkt? Pokazuje stopień złożoności produktu.
SELECT 
	p.Name,
	COUNT(*) AS Ilosc_komponentow
FROM Production.BillOfMaterials bom
JOIN Production.Product p ON bom.ProductAssemblyID = p.ProductID
GROUP BY p.Name
ORDER BY Ilosc_komponentow DESC;

-- Produkty z największym zapotrzebowaniem na komponenty.
SELECT 
	p.Name,
	SUM(bom.PerAssemblyQty) AS Calkowita_suma_czesci
FROM Production.BillOfMaterials bom
JOIN Production.Product p ON bom.ProductAssemblyID = p.ProductID
GROUP BY p.Name
ORDER BY Calkowita_suma_czesci DESC;

-- Które komponenty są używane najczęściej? 
SELECT
    p.Name,
    COUNT(*) AS UsedInProducts
FROM Production.BillOfMaterials bom
JOIN Production.Product p ON bom.ComponentID = p.ProductID
GROUP BY p.Name
ORDER BY UsedInProducts DESC;

-- Produkty wykorzystujące ten sam komponent. W jakich produktach wykorzystywany jest dany komponent?
SELECT
    pc.Name AS Component,
    pa.Name AS Product
FROM Production.BillOfMaterials bom
JOIN Production.Product pc ON bom.ComponentID = pc.ProductID
JOIN Production.Product pa ON bom.ProductAssemblyID = pa.ProductID
ORDER BY Component;

-- Komponenty znajdujące się obecnie w magazynie. Pokazuje stany magazynowe komponentów.
SELECT
    pc.Name AS Component,
    SUM(pi.Quantity) AS Stock
FROM Production.BillOfMaterials bom
JOIN Production.Product pc ON bom.ComponentID = pc.ProductID
JOIN Production.ProductInventory pi ON pc.ProductID = pi.ProductID
GROUP BY pc.Name
ORDER BY Stock DESC;

-- Czy wystarczy komponentów do produkcji? Połączenie komponentów z magazynem.
SELECT
    pa.Name AS Product,
    pc.Name AS Component,
    bom.PerAssemblyQty,
    SUM(pi.Quantity) AS Stock
FROM Production.BillOfMaterials bom
JOIN Production.Product pa ON bom.ProductAssemblyID = pa.ProductID
JOIN Production.Product pc ON bom.ComponentID = pc.ProductID
JOIN Production.ProductInventory pi ON pc.ProductID = pi.ProductID
GROUP BY pa.Name, pc.Name, bom.PerAssemblyQty
ORDER BY Product;

-- Koszt komponentów produktu. Pokazuje szacunkowy koszt materiałów potrzebnych do wyprodukowania jednej sztuki produktu.
SELECT
	pa.Name,
	SUM(pc.StandardCost * bom.PerAssemblyQty) AS MaterialCost
FROM Production.BillOfMaterials bom
JOIN Production.Product pa ON bom.ProductAssemblyID = pa.ProductID
JOIN Production.Product pc ON bom.ComponentID = pc.ProductID
GROUP BY pa.Name
ORDER BY MaterialCost DESC;

-- Analiza jednostkowego kosztu produkcji produktów. Głównym celem jest policzenie średniego kosztu wyprodukowania jednej sztuki produktu 
-- na podstawie kosztów operacji produkcyjnych.
WITH RoutingCost AS
(
    SELECT
        WorkOrderID,
        SUM(PlannedCost) AS ProductionCost
    FROM Production.WorkOrderRouting
    GROUP BY WorkOrderID
)
SELECT
    p.Name,
    SUM(rc.ProductionCost) AS TotalProductionCost,
    SUM(wo.StockedQty) AS ProducedQty,
    ROUND(SUM(rc.ProductionCost) / SUM(wo.StockedQty), 2) AS ProductionCostPerUnit
FROM Production.WorkOrder wo
JOIN RoutingCost rc ON wo.WorkOrderID = rc.WorkOrderID
JOIN Production.Product p ON wo.ProductID = p.ProductID
GROUP BY p.Name;

-- produkcja + BOM, ile wyprodukowano, z ilu różnych komponentów składa się produkt.
SELECT
    pa.Name,
    SUM(wo.StockedQty) AS Produced,
    COUNT(DISTINCT bom.ComponentID) AS Components
FROM Production.WorkOrder wo
JOIN Production.BillOfMaterials bom ON wo.ProductID = bom.ProductAssemblyID
JOIN Production.Product pa ON wo.ProductID = pa.ProductID
GROUP BY pa.Name
ORDER BY Produced DESC;

-- Sprzedaż + BOM, Czy najbardziej złożone produkty sprzedają się najlepiej?
SELECT
    pa.Name,
    SUM(sod.OrderQty) AS Sold,
    COUNT(DISTINCT bom.ComponentID) AS Components
FROM Sales.SalesOrderDetail sod
JOIN Production.Product pa
    ON sod.ProductID = pa.ProductID
JOIN Production.BillOfMaterials bom
    ON pa.ProductID = bom.ProductAssemblyID
GROUP BY pa.Name
ORDER BY Sold DESC;

/* Analiza Klientów i Sprzedaży */ 
SELECT * FROM Sales.Customer;
SELECT * FROM Person.Person;
SELECT * FROM Sales.SalesOrderHeader;
SELECT * FROM Sales.SalesOrderDetail;
SELECT * FROM Sales.Store;

--Najlepsi klienci pod względem wartości zakupów. Pokazuje którzy klienci zostawili najwięcej pieniędzy.
SELECT 
	c.CustomerID,
	CONCAT(pp.FirstName, ' ', pp.LastName) AS Customer,
	SUM(soh.TotalDue) AS TotalSpent
FROM Sales.Customer c
JOIN Person.Person pp ON c.PersonID = pp.BusinessEntityID
JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
GROUP BY c.CustomerID, pp.FirstName, pp.LastName
ORDER BY TotalSpent DESC;

-- Aktywność klientów, czyli liczba złożonych zamówień. Takie zapytanie ma na celu policzenie, ile zamówień złożył każdy klient.
SELECT
    c.CustomerID,
    CONCAT(pp.FirstName, ' ', pp.LastName) AS Customer,
    COUNT(*) AS NumberOfOrders
FROM Sales.Customer c
JOIN Person.Person pp ON c.PersonID = pp.BusinessEntityID
JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
GROUP BY
    c.CustomerID,
    pp.FirstName,
    pp.LastName
ORDER BY NumberOfOrders DESC;

-- Najczęściej kupowane produkty
SELECT 
	p.Name,
	SUM(sod.OrderQty) AS TotalSold
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY TotalSold DESC;

-- Produkty generujące największy przychód
SELECT
    p.Name,
    SUM(sod.LineTotal) AS Calkowita_wartosc
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY Calkowita_wartosc DESC;

-- Sprzedaż miesięczna
SELECT
	YEAR(OrderDate) AS Year,
	MONTH(OrderDate) AS Month,
    SUM(TotalDue) AS Revenue
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY
    Year,
    Month;

--Produkty kupowane przez konkretnego klienta, Co znajdowało się w każdym konkretnym zamówieniu
SELECT
    CONCAT(pp.FirstName,' ',pp.LastName) AS Customer,
    p.Name,
    SUM(sod.OrderQty) AS Quantity,
	soh.SalesOrderID
FROM Sales.Customer c
JOIN Person.Person pp ON c.PersonID = pp.BusinessEntityID
JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product p ON sod.ProductID = p.ProductID
GROUP BY
    pp.FirstName,
    pp.LastName,
    p.Name,
	soh.SalesOrderID
ORDER BY Customer;

-- Zamówienia według kategorii produktów. To pokazuje, które kategorie sprzedają się najlepiej. 
SELECT
    pc.Name AS Category,
    SUM(sod.OrderQty) AS Sold
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
GROUP BY pc.Name
ORDER BY Sold DESC;

-- Produkty niesprzedające się. Można znaleźć produkty zalegające w ofercie.  
SELECT
    p.Name
FROM Production.Product p
LEFT JOIN Sales.SalesOrderDetail sod ON p.ProductID = sod.ProductID
WHERE sod.ProductID IS NULL;

--Produkty niesprzedające się. Można znaleźć produkty zalegające w ofercie i ile sztuk w magazynie
SELECT
	p.Name,
	SUM(pi.Quantity) AS CurrentStock
FROM Production.Product p
LEFT JOIN Sales.SalesOrderDetail sod ON p.ProductID = sod.ProductID
JOIN Production.ProductInventory pi ON p.ProductID = pi.ProductID -- ile sztuk w magazynie
WHERE sod.ProductID IS NULL
GROUP BY p.Name
ORDER BY CurrentStock DESC;

-- Analiza sklepów/firm biznesowych
SELECT * FROM Sales.Store;

-- Policzenie liczby sklepów współpracujących z firmą.
SELECT
    COUNT(*) AS NumberOfStores
FROM Sales.Store;

-- Ilu klientów obsługuje każdy sprzedawca? Sprawdzenie, który handlowiec obsługuje najwięcej sklepów.
SELECT 
		SalesPersonID,
		COUNT(*) AS NumberOfStores
FROM Sales.Store
GROUP BY SalesPersonID
ORDER BY NumberOfStores DESC;

-- Liczba zamówień dla każdego sklepu
SELECT
	s.Name,
	COUNT(soh.SalesOrderID) AS NumberOfOrders
FROM Sales.Store s
JOIN Sales.Customer c ON s.BusinessEntityID = c.StoreID
JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
GROUP BY s.Name
ORDER BY NumberOfOrders DESC;

-- Łączna wartość zamówień każdego sklepu
SELECT 
	s.Name,
	ROUND(SUM(soh.TotalDue),2) AS TotalSales
FROM Sales.Store s
JOIN Sales.Customer c ON s.BusinessEntityID = c.StoreID
JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
GROUP BY s.Name
ORDER BY TotalSales DESC;

-- Średnia wartość jednego zamówienia. Pokazuje, który sklep składa największe zamówienia.
SELECT
    s.Name,
    ROUND(AVG(soh.TotalDue),2) AS AverageOrderValue
FROM Sales.Store s
JOIN Sales.Customer c
    ON s.BusinessEntityID = c.StoreID
JOIN Sales.SalesOrderHeader soh
    ON c.CustomerID = soh.CustomerID
GROUP BY s.Name
ORDER BY AverageOrderValue DESC;

-- Produkty kupowane przez wybrany sklep. Pokazuje historię zakupów jednego sklepu.
SELECT
    s.Name AS Store,
    p.Name AS Product,
    SUM(sod.OrderQty) AS Quantity
FROM Sales.Store s
JOIN Sales.Customer c ON s.BusinessEntityID = c.StoreID
JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product p ON sod.ProductID = p.ProductID
WHERE s.Name = 'Next-Door Bike Store'
GROUP BY
    s.Name,
    p.Name
ORDER BY Quantity DESC;

-- Najczęściej kupowany produkt przez wszystkie sklepy
SELECT
    p.Name,
    SUM(sod.OrderQty) AS TotalSold
FROM Sales.Store s
JOIN Sales.Customer c ON s.BusinessEntityID = c.StoreID
JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product p ON sod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY TotalSold DESC;

-- Sklepy, które jeszcze nic nie zamówiły.
SELECT
	s.Name
FROM Sales.Store s
JOIN Sales.Customer c ON s.BusinessEntityID = c.StoreID
LEFT JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
WHERE soh.SalesOrderID IS NULL;


-- Ranking sklepów według liczby zakupionych produktów
SELECT
    s.Name,
    SUM(sod.OrderQty) AS TotalProductsBought
FROM Sales.Store s
JOIN Sales.Customer c ON s.BusinessEntityID = c.StoreID
JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
GROUP BY s.Name
ORDER BY TotalProductsBought DESC;


/* Promocje */
SELECT * FROM Sales.SpecialOffer;
SELECT * FROM Sales.SpecialOfferProduct;

-- Które promocje były najczęściej wykorzystywane.
SELECT
    so.Description,
    COUNT(*) AS NumberOfSales
FROM Sales.SalesOrderDetail sod
JOIN Sales.SpecialOffer so ON sod.SpecialOfferID = so.SpecialOfferID
GROUP BY so.Description
ORDER BY NumberOfSales DESC;

-- Produkty objęte promocjami. Sprawdzenie, które produkty posiadają przypisaną promocję.
SELECT 
	p.Name,
	so.Description,
	so.DiscountPct,
	so.StartDate
FROM Sales.SpecialOfferProduct sop
JOIN Production.Product p ON sop.ProductID = p.ProductID
JOIN Sales.SpecialOffer so ON sop.SpecialOfferID = so.SpecialOfferID
ORDER BY p.Name;

-- Sprzedaż produktów objętych promocją. Pokazuje liczbę sprzedanych sztuk dla każdej promocji.
SELECT 
	so.Description,
	SUM(sod.OrderQty) AS SoldProducts
FROM Sales.SpecialOffer so
JOIN Sales.SalesOrderDetail sod ON so.SpecialOfferID = sod.SpecialOfferID
GROUP BY so.Description
ORDER BY SoldProducts DESC;

-- Produkty najczęściej kupowane z promocją. Pokazuje, które produkty najczęściej kupowano z wykorzystaniem promocji.
SELECT
    p.Name,
    so.Description,
    SUM(sod.OrderQty) AS QuantitySold
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
JOIN Sales.SpecialOffer so ON sod.SpecialOfferID = so.SpecialOfferID
GROUP BY
    p.Name,
    so.Description
ORDER BY QuantitySold DESC;

SELECT
    p.Name,
    so.Description,
    SUM(sod.OrderQty) AS QuantitySold
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
JOIN Sales.SpecialOffer so ON sod.SpecialOfferID = so.SpecialOfferID
WHERE p.Name = 'Adjustable Race'
GROUP BY
    p.Name,
    so.Description
ORDER BY QuantitySold DESC;


-- Łączna wartość sprzedaży według promocji. Sprawdzenie, która promocja wygenerowała największą sprzedaż.
SELECT
	so.Description,
	ROUND(SUM(sod.LineTotal),2) AS TotalSales
FROM Sales.SalesOrderDetail sod
JOIN Sales.SpecialOffer so ON sod.SpecialOfferID = so.SpecialOfferID
GROUP BY so.Description
ORDER BY TotalSales DESC;

-- Klienci korzystający z promocji. Pokazuje, którzy klienci najczęściej kupowali produkty objęte promocją.
SELECT
    CONCAT(pp.FirstName,' ',pp.LastName) AS Customer,
    so.Description,
    COUNT(*) AS NumberOfPurchases
FROM Sales.Customer c
JOIN Person.Person pp ON c.PersonID = pp.BusinessEntityID
JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN Sales.SpecialOffer so ON sod.SpecialOfferID = so.SpecialOfferID
WHERE so.Description <> 'No Discount'
GROUP BY
    pp.FirstName,
    pp.LastName,
    so.Description
ORDER BY NumberOfPurchases DESC;

-- Największe rabaty. Pozwala szybko znaleźć najwyższe rabaty oferowane przez firmę.
SELECT
    Description,
    DiscountPct
FROM Sales.SpecialOffer
ORDER BY DiscountPct DESC;

-- Produkty bez promocji
SELECT 
	p.Name
FROM Production.Product p
LEFT JOIN Sales.SpecialOfferProduct sop ON p.ProductID = sop.ProductID
WHERE sop.ProductID IS NULL
ORDER BY p.Name;











