1. VPD 실습 계정 및 데이터 만들기
 
1.1 실습 계정 만들기

 VPD 실습을 위한 DB 계정은 "HANDSON"이며, password는 "HANDSON" 입니다. 
 VPD 운영에 필요한 기본 권한은 CREATE SESSION, CREATE ANY CONTEXT, CREATE PROCEDURE, CREATE TRIGGER, ADMINISTER DATABASE TRIGGER, EXEMPT ACCERSS POLICY과 EXEXUTE on dbms_session, EXECUTE on DBMS_RLS입니다.
 아래 스크립트를 이용하여 데이터 owner 계정 및 권한을 부여합니다.

 
sqlplus / as sysdba

create user handson identified by handson default tablespace users quota unlimited on users;
GRANT CONNECT, RESOURCE to handson;

-- GRANT EXEMPT ACCESS POLICY TO handson;


아래 쿼리를 이용하여 생성된 DB 계정 정보를 확인 합니다.

set line 150
col username format a20
col account_status format a10

select username, account_status, created from dba_users;

~~~~~~ 생략


1.2 실습 데이터를 위한 테이블 만들기

conn handson/handson

create table evaluate_t (
empno varchar2(12) not null,
fst_ev_grade varchar2(2),
snd_ev_grade varchar2(2),
fin_ev_grade varchar2(2),
emp_sosok_cd  varchar2(4) not null,
emp_sb_cd varchar2(6) not null);

create table account_t (
acct_id varchar2(20) not null,
data_zone varchar2(20) not null,
sosok varchar2(20),
sosok_br varchar(20),
s_role varchar2(20));

col table_name format a30

select table_name, status from user_tables where table_name in ('EVALUATE_T','ACCOUNT_T');

TABLE_NAME                     STATUS
------------------------------ ------------------------
ACCOUNT_T                      VALID
EVALUATE_T                     VALID


1.3 실습 데이터 데이터 로딩

VPD 실습을 위해 별도 제공되는 쉘스크립트와 가상데이터를 사용하여 위에서 만든 테이블에 데이터를 입력합니다. 데이터 로딩 툴은 SQL*LOADER를 사용합니다.
별도 제공되는 쉘스크립트와 가상데이터 목록은 다음과 같습니다.

account_dataset4vpd.dat     -- account_t 테이블을 위한 데이터 셋 
Evaluate_dataset.dat        -- evaluate_t 테이블을 위한 데이터 셋 
load_acc.ctl                -- account_t 테이블의 데이터 로딩 control 파일
load_acc.sh                 -- account_t 테이블의 데이터 로딩 쉘
load_evl.ctl                --evaluate_t 테이블의 데이터 로딩 control 파일
load_evl.sh                 -- evaluate_t 테이블의 데이터 로딩 쉘

데이터 로딩을 마쳤으면 아래와 같이 데이터를 확인 합니다.

sqlplus handson/handson
set pagesize 100
set line 200
col acct_id format a20
col data_zone format a20

select acct_id, data_zone from account_t;

ACCT_ID              DATA_ZONE
-------------------- ----------
ADMINAR              AR
ADMINARMC            ARMC
ADMINARAD            ARMIL
ADMINNV              NV
ADMINAF              AF

select * from evaluate_t;

EMPNO        FST_EV SND_EV FIN_EV EMP_SOSOK_CD EMP_SB_CD
------------ ------ ------ ------ ------------ ------------------
21-10011     4      4             AR           MIL
21-10102     1      2      2      AR           MIL
21-10203     2      2      2      AR           MIL
21-10044     3      3      2      AR           MC
21-15005     3      3      3      AR           MIL
21-10106     1      5             AR           MC
21-10307     2      1      1      AR           MIL
21-10038     2      2      2      AR           MIL
21-10009     1      2      2      AR           MIL
21-11010     2      3      3      AR           MIL
21-20301     4      4             NV           MIL
21-20002     2      2      2      NV           MIL
21-20343     1      2      2      NV           MIL
21-20104     2      2      2      NV           MIL
21-20235     4      3      3      NV           MC
21-21106     1      1             NV           MIL
21-20207     1      2      1      NV           MIL
21-21008     2      2      2      NV           MC
21-20459     1      2      2      NV           MIL
21-20210     2      3      3      NV           MIL
21-30001     1      2      2      AF           MIL
21-31102     2      2      2      AF           MIL
21-33203     2      2      2      AF           MIL
21-30004     2      3             AF           MC
21-30905     2      1      1      AF           MIL
21-30806     1      2             AF           MIL
21-30047     2      2      2      AF           MC
21-30078     3      2      2      AF           MIL
21-30309     3      3      3      AF           MIL
21-30010     2      2      2      AF           MIL


select emp_sosok_cd, count(*) from evaluate_t group by emp_sosok_cd;
EMP_MIL_CD     COUNT(*)
------------ ----------
AR                   10
NV                   10
AF                   10

select emp_sb_cd, count(*) from evaluate_t 
where emp_sosok_cd = 'AR' and emp_sb_cd in ('MIL','MC') 
group by emp_sb_cd;

EMP_SB_CD            COUNT(*)
------------------ ----------
MC                          2
MIL                         8


1.4 Application 계정 만들기

VPD 실습에 사용되는 Application 계정은 APPUSER, ADMINAR, ADMINARMC, ADMINARNIL, ADMINNV, ADMINAF 등 6개의 DB 계정을 사용합니다. 아래 스크립트를 이용하여 DB 계정을 생성합니다.


conn / as sysdba
show user;

CREATE USER appuser IDENTIFIED BT wlcome1 DEFAULT TABLESPACE users;
GRANT connect,resource to appuser ;
GRANT CREATE SESSION, CREATE ANY CONTEXT, CREATE PROCEDURE, CREATE TRIGGER, ADMINISTER DATABASE TRIGGER TO appuser;
GRANT EXECUTE ON DBMS_SESSION TO appuser;
GRANT EXECUTE ON DBMS_RLS TO appuser;

create user adminar identified by welcome1 default tablespace users;
grant connect to adminar;

create user adminnv identified by welcome1 default tablespace users;
grant connect to adminnv;

create user adminaf identified by welcome1 default tablespace users;
grant connect to adminaf;

create user adminarmil identified by welcome1 default tablespace users;
grant connect to adminarmil;

create user adminarmc identified by welcome1 default tablespace users;
grant connect to adminarmc;


1.5 테이블 액세스 권한 부여

위에서 만든 테이블 및 데이터를 사용하기 위해 각가의 Application 계정에게 SELECT, INSERT, UPDATE, DELETE 권한을 부여합니다.

conn handson/handson

grant select, insert, update, delete on account_t to appuser, adminar, adminnv, adminaf, adminarmil, adminarmc;

grant select, insert, update, delete on evaluate_t to appuser, adminar, adminnv, adminaf, adminarmil, adminarmc;

1.6 사용자별 데이터 액세스 확인
conn appuser/welcome1

column empno format a12
select * from handson.evaluate_t ;

EMPNO        FST_EV SND_EV FIN_EV EMP_SOSOK_CD EMP_SB_CD
------------ ------ ------ ------ ------------ ------------------
21-10011     4      4             AR           MIL
21-10102     1      2      2      AR           MIL
21-10203     2      2      2      AR           MIL
21-10044     3      3      2      AR           MC
21-15005     3      3      3      AR           MIL
21-10106     1      5             AR           MC
21-10307     2      1      1      AR           MIL
21-10038     2      2      2      AR           MIL
21-10009     1      2      2      AR           MIL
21-11010     2      3      3      AR           MIL
21-20301     4      4             NV           MIL
21-20002     2      2      2      NV           MIL
21-20343     1      2      2      NV           MIL
21-20104     2      2      2      NV           MIL
21-20235     4      3      3      NV           MC
21-21106     1      1             NV           MIL
21-20207     1      2      1      NV           MIL
21-21008     2      2      2      NV           MC
21-20459     1      2      2      NV           MIL
21-20210     2      3      3      NV           MIL
21-30001     1      2      2      AF           MIL
21-31102     2      2      2      AF           MIL
21-33203     2      2      2      AF           MIL
21-30004     2      3             AF           MC
21-30905     2      1      1      AF           MIL
21-30806     1      2             AF           MIL
21-30047     2      2      2      AF           MC
21-30078     3      2      2      AF           MIL
21-30309     3      3      3      AF           MIL
21-30010     2      2      2      AF           MIL

30 행이 선택되었습니다.

conn adminarmil/welcome1

column empno format a12
select * from handson.evaluate_t ;

EMPNO        FST_EV SND_EV FIN_EV EMP_SOSOK_CD EMP_SB_CD
------------ ------ ------ ------ ------------ ------------------
21-10011     4      4             AR           MIL
21-10102     1      2      2      AR           MIL
21-10203     2      2      2      AR           MIL
21-10044     3      3      2      AR           MC
21-15005     3      3      3      AR           MIL
21-10106     1      5             AR           MC
21-10307     2      1      1      AR           MIL
21-10038     2      2      2      AR           MIL
21-10009     1      2      2      AR           MIL
21-11010     2      3      3      AR           MIL
21-20301     4      4             NV           MIL
21-20002     2      2      2      NV           MIL
21-20343     1      2      2      NV           MIL
21-20104     2      2      2      NV           MIL
21-20235     4      3      3      NV           MC
21-21106     1      1             NV           MIL
21-20207     1      2      1      NV           MIL
21-21008     2      2      2      NV           MC
21-20459     1      2      2      NV           MIL
21-20210     2      3      3      NV           MIL
21-30001     1      2      2      AF           MIL
21-31102     2      2      2      AF           MIL
21-33203     2      2      2      AF           MIL
21-30004     2      3             AF           MC
21-30905     2      1      1      AF           MIL
21-30806     1      2             AF           MIL
21-30047     2      2      2      AF           MC
21-30078     3      2      2      AF           MIL
21-30309     3      3      3      AF           MIL
21-30010     2      2      2      AF           MIL

30 행이 선택되었습니다.



똑 같은 방법으로 adminaf, adminnv 등의 다른 계정으로 로그인 하여 evaluate_t 테이블의 데이터가 조회되는지 확인 합니다.


