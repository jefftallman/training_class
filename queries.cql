CALL algo.louvain(
  'MATCH (p:AccountHolder) RETURN id(p) as id',
  'MATCH (p1:AccountHolder)-[]-()-[]-(p2:AccountHolder) where id(p1) <> id(p2)
   RETURN id(p1) as source, id(p2) as target, count(*) as weight',
  {graph:'cypher', iterations:5, write: true})
  
MATCH (n:AccountHolder) with n.community as community,count(n.community) as cCount where cCount > 1
match (a:AccountHolder {community:community}) set a.cCount=cCount
return a


MATCH path1=(od:CalendarDate)<-[DATE_OPENED]-(a:Account)-
		[WAS_LATE]->(lp:LatePayments),
    path2=(a2:Account)-[APPEARED_ON]-(i:Inquiry)-[]->(iq:CalendarDate)
WHERE daysLate>60  AND iq<od
RETURN path1, path2


MATCH (b:FI)<-[CONTRIBUTED_FRAUD]-(af:Account)-[]-(p)-[]-(an:Account)-[]-(b2:FI)
WHERE id(af)<>id(an)
AND b.ClosedRelation=true


CREATE (SeqNum {seq: toInt(0)})


MATCH (SeqNum)
With seq as sequence
MATCH P, seq
WITH P, seq LIMIT 1000
WHERE p.person_id IS NULL
SET p.person_id=seq, seq=seq+1


// Account Aggregators
MATCH p=(t:Transaction)-[:SEND]->(ba:BankAccount)-[:FROM]->(fi:FinancialInstitute)-[:IN_COUNTRY]->(c:Country)
WHERE c.code<>'US'
WITH ba, date.truncate('month',date(t.transactionDate)) as Month,  sum(t.amount) as Total,  count(ba) as numSend
WHERE Total > 9999
//MATCH pm=(c2:Country)<-[:IN_COUNTRY]-(fi2:FinancialInstitute)<-[:FROM]-(ba2:BankAccount)-[:SEND*1..1]->(ba)-[:FROM]->(fi)-[:IN_COUNTRY]->(c) 
//MATCH pm=(c2:Country)<-[:IN_COUNTRY]-(fi2:FinancialInstitute)<-[:FROM]-(ba2:BankAccount)
MATCH pm=(ba2:BankAccount)-[:SEND]->(t)-[:SEND]->(ba)-[:FROM]->(fi)-[:IN_COUNTRY]->(c) 
RETURN pm

// Circular Money Flows
MATCH p=(ah:AccountHolder)-[:HAS_BANKACCOUNT]->(ba)-[:SEND|WITH*4..14]->(ba)
RETURN  p

// High Risk for Fraud
MATCH (accountHolder:AccountHolder)-[:HAS_SSN|HAS_EMAIL|HAS_PHONENUMBER|HAS_ADDRESS]->(contactInformation)
WITH contactInformation, count(accountHolder) AS RingSize, 
collect(accountHolder) AS FraudRing 
WHERE RingSize > 3 UNWIND FraudRing as fraudPerson 
return fraudPerson


MATCH (accountHolder:AccountHolder)-[]->(contactInformation)
WITH contactInformation, count(accountHolder) AS RingSize , collect(id(accountHolder)) AS _FraudRing order by RingSize desc limit 7 
MATCH (contactInformation)<-[]-(accountHolder2:AccountHolder) ,  
	(accountHolder2)-[r:HAS_CREDITCARD|HAS_UNSECUREDLOAN|HAS_SSN]->(unsecuredAccount) 
RETURN accountHolder2

// Account Holder Transactions
MATCH p=(ah:AccountHolder)-[:HAS_BANKACCOUNT]->(ba)-[:SEND*2..15]-()
WHERE id(ah)={{"Account Holder":node:"AccountHolder" }}
return  p 

"Purchase from shop on date"
"Purchases from $shop on $date",
MATCH (s:Shop)-[r]-(a:Login)-[r2]-(p:Purchase) 
WHERE s.name=$shop AND p.date=\"2018-02-07\"
RETURN s, r, a, r2,  p


// International Money Transfers
MATCH (fromCountry:Country) WHERE fromCountry.name={{"From Country":string}}
MATCH (toCountry:Country) WHERE toCountry.name={{"To Country":string}}
MATCH p=(fromCountry)<-[:IN_COUNTRY]-()<-[:FROM]-(ba)-[:SEND|FROM*1..10]->(fin)-[:IN_COUNTRY]->(toCountry)
with p, tail([x in nodes(p) where x:BankAccount]) as accounts
unwind accounts as acc 
match p2=(acc)-[:FROM|IN_COUNTRY*1..2]->(aCountry)
return p, p2 LIMIT 750


// Risky Accounts (expand)

MATCH path=(ah1:AccountHolder)-[:HAS_SSN|HAS_EMAIL|HAS_PHONENUMBER|HAS_ADDRESS]->(contactInformation)<-[:HAS_SSN|HAS_EMAIL|HAS_PHONENUMBER|HAS_ADDRESS]-(ah2:AccountHolder)
WHERE id(ah1)<>id(ah2)
AND id(ah1) IN {{"Account Holders":nodeset:"AccountHolder"}}
RETURN path






-- Show fraud RingSize
MATCH p=(a1:AccountHolder)-[:HAS_ADDRESS|HAS_SSN|HAS_EMAIL|HAS_PHONENUMBER|FROM_IP]->(info)<-[:HAS_ADDRESS|HAS_SSN|HAS_EMAIL|HAS_PHONENUMBER|FROM_IP]-(a2:AccountHolder)
//OPTIONAL MATCH p2=(a1)-[:HAS_BANKACCOUNT]->(ba:BankAccount)-[*1..4]-(ba2:BankAccount)<-[:HAS_BANKACCOUNT]-(a2)
WHERE a1<>a2
RETURN p //, p2 LIMIT 750



-- Transaction chain & countries from account
MATCH p=(ah:AccountHolder {fullName :$accountName })-[:HAS_BANKACCOUNT]->(ba)-[:SEND*2..16]->()
WITH p, [x IN nodes(p) WHERE x:BankAccount] as mts
UNWIND mts as mt
MATCH p2=(mt)-[:FROM]->()-[:IN_COUNTRY]->()
RETURN p, p2 





gli_source						transaction_amount			

CREATE CONSTRAINT ON (acct:DDA_Account) ASSERT (acct.accountNumber) IS UNIQUE;
CREATE CONSTRAINT ON (txns:DDA_Transactions) ASSERT (txns.transactionID) IS UNIQUE;
CREATE INDEX ON :DDA_Transactions(postedDate,postSequence);
CREATE CONSTRAINT ON (branch:DDA_RetailBranches) ASSERT (branch.branchNumber) IS UNIQUE;
CREATE CONSTRAINT ON (func:DDA_AccountFunction) ASSERT (func.functionID) IS UNIQUE;
CREATE CONSTRAINT ON (payee:DDA_PayeeDescription) ASSERT (payee.payeeDescription) IS UNIQUE;
CREATE CONSTRAINT ON (payee:DDA_PayeeDescription) ASSERT (payee.payeeUUID) IS UNIQUE;

LOAD CSV WITH HEADERS FROM 'file:///Clean_Simple_DDA_Transactions.csv' AS input
MERGE (acct:DDA_Account {accountNumber: toString(input.account_number)})
MERGE (branch:DDA_RetailBranches {branchNumber: toInteger(input.branch_number)})
MERGE (func:DDA_AccountFunction {functionID: toInteger(input.function_id)})
MERGE (payee:DDA_PayeeDescription {payeeDescription: input.transaction_description}) ON CREATE SET payee.payeeUUID=randomUUID()
MERGE (txn:DDA_Transactions {transactionID: toString(input.transaction_id)})
	ON CREATE SET txn.accountNumber=toString(input.account_number),
								txn.branchNumber=toInteger(input.branch_number),
								txn.functionID=toInteger(input.function_id),
								txn.transactionDate=input.date_transaction_started,
								txn.postedDate=input.date_transaction_posted,
								txn.postSequence=toInteger(input.post_sequence),
								txn.transactionType=CASE input.credit_or_debit WHEN 'C' THEN 'CREDIT' ELSE 'DEBIT' END,
								txn.transcationAmount=input.transaction_amount,
								txn.transactionCash=input.transaction_cash_amount,
								txn.acctBalance=CASE input.ledger_sign WHEN '-' THEN -1.0*toFloat(input.ledger_balance_post_transaction) ELSE toFloat(input.ledger_balance_post_transaction) END,
								txn.payeeUUID=payee.payeeUUID
MERGE (acct)-[:HAS_TRANSACTIONS]->(txn)
MERGE (txn)-[:OCCURRED_AT]->(branch)
MERGE (txn)-[:EXECS_FUNCTION]->(func)
MERGE (txn)-[:HAS_PAYEE]->(payee)
--Added 1411 labels, created 1411 nodes, set 9752 properties, created 3658 relationships, completed after 283 ms.


MATCH (txn1:DDA_Transactions), (txn2:DDA_Transactions)
WHERE txn1.transactionID=txn2.transactionID
  AND txn1.postDate=txn2.postDate
  AND txn1.postSequence=txn2.postSequence-1
RETURN txn1