## 오라클 VPD(Virtual Private Database) example
------
 이 예제는 Oracle 12c VPD를 이용하여 table row에 대한 계정별 CRUD(insert, select, update, delete)를 구현 한 예제이며, DB 로그인 계정의 세션 사용자(session_user) 정보를 이용하여 통제하는 방법을 제공합니다.

고운용(kairkowy69@gmail.com) 2020.6월

#### 1. 데모 환경
- DB 스키마(계정)
  - insa  : table의 owner 계정
  - insa_army : ‘육군’ 데이터에 대한 RW 권한을 가지는 계정
  - insa_navy : ‘해군’ 데이터에 대한 RW 권한을 가지는 계정
  - insa_af : ‘공군’ 데이터에 대한 RW 권한을 가지는 계정
  - Insa_ev : RW 권한이 없는 테스트 계정

- DB 오브젝트들
  - gun_code_t 테이블 : DB 스키마 계정과 소속군(gun_code) 정보를 맵핑해 주는 정보 테이블, 소속군(gun_code) 값으로 Row 데이터에 대한 RW 통제를 하기 위한 기본 정보
  - sosok_t 테이블 : 스키마 계정별로 RW 통제가 필요한 테이블

### 2. 스키마 생성
```sql
connect / as sysdba

create user insa identified by insa default tablespace users quota unlimited on users;
grant connect, resource to insa;
grant execute on dbms_fga to insa;
grant execute on dbms_rls to insa;
grant create session, create any context, create procedure, create trigger, administer database trigger to insa;
GRANT EXEMPT ACCESS POLICY TO insa;

create user insa_army identified by insa_army default tablespace users;
grant connect to insa_army;

create user insa_navy identified by insa_navy default tablespace users;
grant connect to insa_navy;

create user insa_af identified by insa_af default tablespace users;
grant connect to insa_af;

create user insa_ev identified by insa_ev default tablespace users;
grant connect to insa_ev;

```
### 3. 오브젝트 생성 및 RW 권한 부여
```sql
conn insa/insa

create table gun_code_t(gun_code varchar2(10) unique, gun_name varchar2(10), gun_id varchar2(30));
insert into gun_code_t values('1','육군','INSA_ARMY');
Insert into gun_code_t values('2','해군','INSA_NAVY');
insert into gun_code_t values('3','공군','INSA_AF');
commit
/

create table sosok_t (gun_code varchar2(10), gunbun varchar2(20), name varchar2(20));
insert into sosok_t values('1','92-10001', '이영규');
insert into sosok_t values('2','92-10002', '최태철');
insert into sosok_t values('3','92-10003', '고태형');
insert into sosok_t values('1','92-10005', '김희웅');
insert into sosok_t values('1','92-10006', '김영철');
commit
/

grant select, update, delete, insert on sosok_t to insa_army, insa_navy, insa_af, insa_ev;
```

### 3. DB 세션 기반 Application Context 생성
```sql
Conn insa/insa

CREATE OR REPLACE CONTEXT users_ctx USING users_ctx_pkg;
```

### 4. Application Context를 지정하기  위한 PL/SQL Package 생성
```sql
Conn insa/insa

CREATE OR REPLACE PACKAGE users_ctx_pkg IS
  PROCEDURE set_usernum;
 END;
/

CREATE OR REPLACE PACKAGE BODY users_ctx_pkg IS
  PROCEDURE set_usernum
  AS
    usernum varchar2(10);
  BEGIN
     SELECT gun_code INTO usernum FROM gun_code_t
        WHERE gun_id = SYS_CONTEXT('USERENV', 'SESSION_USER');
     DBMS_SESSION.SET_CONTEXT('users_ctx', 'gun_code', usernum);
  EXCEPTION
   WHEN NO_DATA_FOUND THEN NULL;
  END set_usernum;
END;
/
```

### 5. Application Context PL/SQL Packag 실행을 위한 로그온 트리거 생성 및 테스트
```sql
CREATE TRIGGER set_userno_ctx_trig AFTER LOGON ON DATABASE
 BEGIN
  INSA.users_ctx_pkg.set_usernum;
 END;
/


conn insa_army/insa_army
SELECT SYS_CONTEXT('users_ctx', 'gun_code') usernum FROM DUAL;
```

### 6. 사용자 접속제어를 위한 policy 생성
```sql
conn insa/insa

CREATE OR REPLACE FUNCTION vpd_get_users(
  schema_p   IN VARCHAR2,
  table_p    IN VARCHAR2)
 RETURN VARCHAR2
 AS
  users_pred VARCHAR2 (400);
 BEGIN
  users_pred := 'gun_code = SYS_CONTEXT(''users_ctx'', ''gun_code'')';
 RETURN users_pred;
END;
/
```

### 7. Security Policy 생성
```sql
conn insa/insa

exec bms_rls.add_policy(object_schema=>'insa',object_name=>'sosok_t',policy_name=>'gun_policy',
function_schema=>'insa',policy_function=>'vpd_get_users',
statement_types=>'SELECT,UPDATE,INSERT,DELETE',
policy_type=>DBMS_RLS.CONTEXT_SENSITIVE,
namespace=>'users_ctx',attribute=>'gun_code',
update_check=>TRUE, enable=>TRUE);
```

### 8. Secirity Policy 테스트
```sql
conn insa_army/insa_army
select * from insa.sosok_t;

insert into insa.sosok_t values ('1','92-10111','고프로');
commit;

update insa.sosok_t set gun_code = '2' where gunbun = '92-10111';
==> ORA-28115: policy with check option violation

delete from insa.sosok_t where gunbun = '92-10002';
==> 0 rows deleted.

insert into insa.sosok_t values ('2','92-102000','양프로');
==> ORA-28115: policy with check option violation
conn insa_af/insa_af
select * from insa.sosok_t;
insert into insa.sosok_t values ('3','92-10300','강프로');
commit;

insert into insa.sosok_t values ('1','92-10300','강프로');
==> ORA-28115: policy with check option violation


conn insa_ev/insa_ev
select * from insa.sosok_t;

```

### 9. 예제 정리
```sql
Conn insa/insa
EXEC DBMS_RLS.DROP_POLICY(‘insa’,’sosok_t’,’gun_policy’);
DROP FUNCTION vpd_get_users ;
DROP CONTEXT users_ctx;
```
