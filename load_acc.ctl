load data
infile  './account_dataset4vpd.dat'
into table account_t
fields terminated by ','
( acct_id,
data_zone,
sosok,
sosok_br,
s_role
) 

