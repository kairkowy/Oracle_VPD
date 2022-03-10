** Oracle Security-VPD, Group Policy 실습 

0. 실습 데이터 생성
// 실습을 위한 사용자 계정은 별도 자료를 참조하세요.


3.1 사용자 정보 생성 

conn appuser/welcome1

CREATE OR REPLACE CONTEXT datazone_ctx USING datazone_ctx_pkg;

CREATE OR REPLACE PACKAGE datazone_ctx_pkg IS 
  PROCEDURE set_datazone;
 END;
/
CREATE OR REPLACE PACKAGE BODY datazone_ctx_pkg IS
  PROCEDURE set_datazone
  AS
    datazone varchar2(20);
  BEGIN
     SELECT data_zone INTO datazone FROM handson.account_t
        WHERE acct_id = SYS_CONTEXT('USERENV', 'SESSION_USER');
        DBMS_SESSION.SET_CONTEXT('datazone_ctx', 'data_zone', datazone);
  EXCEPTION
   WHEN NO_DATA_FOUND THEN NULL;
  END set_datazone;
END;
/


3.2 Policy group 생성

conn appuser/welcome1

BEGIN
 DBMS_RLS.CREATE_POLICY_GROUP(
 object_schema   => 'handson',
 object_name     => 'evaluate_t',
 policy_group    => 'sosok_group');
END;
/

BEGIN
 DBMS_RLS.CREATE_POLICY_GROUP(
 object_schema   => 'handson',
 object_name     => 'evaluate_t',
 policy_group    => 'sb_group');
END;
/

3.2 Fuction 생성 

CREATE OR REPLACE FUNCTION vpd_function_sosok_group 
 (schema in varchar2, tab in varchar2) return varchar2 
 as predicate  varchar2(1000) default NULL ;
  BEGIN
   IF LOWER(SYS_CONTEXT('datazone_drv_ctx','policy_group')) = 'sosok_group' 
      THEN predicate := 'emp_sosok_cd = SYS_CONTEXT(''datazone_ctx'',''data_zone'')'; 
   ELSE Null;
  END IF;
  RETURN predicate;
END;
/

CREATE OR REPLACE FUNCTION vpd_function_sb_group 
 (schema in varchar2, tab in varchar2) return varchar2 as 
  predicate  varchar2(2000) default NULL;
  BEGIN
   IF LOWER(SYS_CONTEXT('datazone_drv_ctx','policy_group')) = 'sb_group' 
    THEN predicate := 'emp_sb_cd = SUBSTR(SYS_CONTEXT(''datazone_ctx'',''data_zone''),3,3) and 
    emp_sosok_cd = SUBSTR(SYS_CONTEXT(''datazone_ctx'',''data_zone''),1,2)';
   ELSE Null;
  END IF;
  RETURN predicate;
END;
/

3.3 Driving Application Context 생성

conn appuser/welcome1

CREATE OR REPLACE CONTEXT datazone_drv_ctx USING datazone_drv_ctx_pkg;

CREATE OR REPLACE PACKAGE datazone_drv_ctx_pkg IS 
  PROCEDURE set_drv_context (policy_group varchar2 default NULL);
 END;
/
CREATE OR REPLACE PACKAGE BODY datazone_drv_ctx_pkg IS
  PROCEDURE set_drv_context (policy_group varchar2 default NULL) IS
  BEGIN
  CASE LOWER(SYS_CONTEXT('datazone_ctx', 'data_zone'))
    WHEN 'ar' THEN
        DBMS_SESSION.SET_CONTEXT('datazone_drv_ctx','policy_group','SOSOK_GROUP');
    WHEN 'nv' THEN
        DBMS_SESSION.SET_CONTEXT('datazone_drv_ctx','policy_group','SOSOK_GROUP');
    WHEN 'af' THEN
        DBMS_SESSION.SET_CONTEXT('datazone_drv_ctx','policy_group','SOSOK_GROUP');        
    WHEN 'armil' THEN
        DBMS_SESSION.SET_CONTEXT('datazone_drv_ctx','policy_group','SB_GROUP');    
    WHEN 'armc' THEN
        DBMS_SESSION.SET_CONTEXT('datazone_drv_ctx','policy_group','SB_GROUP');          
  END CASE;
  END set_drv_context;
END;
/

3.4 Context 추가
conn appuser/welcome1

BEGIN
 DBMS_RLS.ADD_POLICY_CONTEXT(
 object_schema  =>'handson',
 object_name    =>'evaluate_t',
 namespace      =>'datazone_drv_ctx',
 attribute      =>'policy_group');
END;
/


3.5 사용자 세션 trigger 생성


CREATE or REPLACE TRIGGER set_datazone_ctx_trig AFTER LOGON ON DATABASE
 BEGIN
    appuser.datazone_ctx_pkg.set_datazone;
   EXCEPTION
   WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR(
    -20000, 'Trigger handson.datazone_ctx_pkg.set_datazone violation. Login denied.');
 END;
 /

 CREATE or REPLACE TRIGGER set_datazone_drv_ctx_trig AFTER LOGON ON DATABASE
 BEGIN
    appuser.datazone_drv_ctx_pkg.set_drv_context;
  EXCEPTION
  WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR(
    -20000, 'Trigger handson.datazone_drv_ctx_pkg.set_drv_context violation. Login denied.');
 END;
/


사용자 정보 확인 
conn adminarmil/welcome1

-- exec handson.datazone_drv_ctx_pkg.set_drv_context;
col datazone format a20
select sys_context('datazone_ctx', 'data_zone') DATAZONE from dual;

DATAZONE
--------------------
ARMIL


col DriveGroup format a20
select sys_context('datazone_drv_ctx','policy_group') DriveGroup from dual;

DRIVEGROUP
--------------------
SB_GROUP


3.6 Driving Context를 Function에 추가 

conn appuser/welcome1

BEGIN 
 DBMS_RLS.ADD_GROUPED_POLICY(
 object_schema         => 'handson',
 object_name           => 'evaluate_t',
 policy_group          => 'sosok_group',
 policy_name           => 'filter_sosok_policy',
 function_schema       => 'appuser',
 policy_function       => 'vpd_function_sosok_group',
 statement_types       => 'select',
 policy_type           => DBMS_RLS.CONTEXT_SENSITIVE,
 namespace             => 'datazone_drv_ctx',
 attribute             => 'policy_group');
END;
/

BEGIN 
 DBMS_RLS.ADD_GROUPED_POLICY(
 object_schema         => 'handson',
 object_name           => 'evaluate_t',
 policy_group          => 'sb_group',
 policy_name           => 'filter_sb_policy',
 function_schema       => 'appuser',
 policy_function       => 'vpd_function_sb_group',
 statement_types       => 'select',
 policy_type           => DBMS_RLS.CONTEXT_SENSITIVE,
 namespace             => 'datazone_drv_ctx',
 attribute             => 'policy_group' );
END;
/


3.7 테스트 

conn adminar/welcome1
set line 200
select * from handson.evaluate_t ;

EMPNO                                FST_EV SND_EV FIN_EV EMP_SOSOK_CD EMP_SB_CD
------------------------------------ ------ ------ ------ ------------ ------------------
21-10011                             4      4             AR           MIL
21-10102                             1      2      2      AR           MIL
21-10203                             2      2      2      AR           MIL
21-10044                             3      3      2      AR           MC
21-15005                             3      3      3      AR           MIL
21-10106                             1      5             AR           MC
21-10307                             2      1      1      AR           MIL
21-10038                             2      2      2      AR           MIL
21-10009                             1      2      2      AR           MIL
21-11010                             2      3      3      AR           MIL

10 행이 선택되었습니다.


conn adminarmil/welcome1
set line 200
select * from handson.evaluate_t ;


EMPNO                                FST_EV SND_EV FIN_EV EMP_SOSOK_CD EMP_SB_CD
------------------------------------ ------ ------ ------ ------------ ------------------
21-10011                             4      4             AR           MIL
21-10102                             1      2      2      AR           MIL
21-10203                             2      2      2      AR           MIL
21-15005                             3      3      3      AR           MIL
21-10307                             2      1      1      AR           MIL
21-10038                             2      2      2      AR           MIL
21-10009                             1      2      2      AR           MIL
21-11010                             2      3      3      AR           MIL

8 행이 선택되었습니다.

conn adminnv/welcome1
set line 200
select * from handson.evaluate_t ;

EMPNO                                FST_EV SND_EV FIN_EV EMP_SOSOK_CD EMP_SB_CD
------------------------------------ ------ ------ ------ ------------ ------------------
21-20301                             4      4             NV           MIL
21-20002                             2      2      2      NV           MIL
21-20343                             1      2      2      NV           MIL
21-20104                             2      2      2      NV           MIL
21-20235                             4      3      3      NV           MC
21-21106                             1      1             NV           MIL
21-20207                             1      2      1      NV           MIL
21-21008                             2      2      2      NV           MC
21-20459                             1      2      2      NV           MIL
21-20210                             2      3      3      NV           MIL

10 행이 선택되었습니다.

conn adminaf/welcome1
set line 200

select * from handson.evaluate_t ;

EMPNO                                FST_EV SND_EV FIN_EV EMP_SOSOK_CD EMP_SB_CD
------------------------------------ ------ ------ ------ ------------ ------------------
21-30001                             1      2      2      AF           MIL
21-31102                             2      2      2      AF           MIL
21-33203                             2      2      2      AF           MIL
21-30004                             2      3             AF           MC
21-30905                             2      1      1      AF           MIL
21-30806                             1      2             AF           MIL
21-30047                             2      2      2      AF           MC
21-30078                             3      2      2      AF           MIL
21-30309                             3      3      3      AF           MIL
21-30010                             2      2      2      AF           MIL

10 행이 선택되었습니다.

conn adminarmil/welcome1
set line 200

select * from handson.evaluate_t ;


EMPNO                                FST_EV SND_EV FIN_EV EMP_SOSOK_CD EMP_SB_CD
------------------------------------ ------ ------ ------ ------------ ------------------
21-10011                             4      4             AR           MIL
21-10102                             1      2      2      AR           MIL
21-10203                             2      2      2      AR           MIL
21-15005                             3      3      3      AR           MIL
21-10307                             2      1      1      AR           MIL
21-10038                             2      2      2      AR           MIL
21-10009                             1      2      2      AR           MIL
21-11010                             2      3      3      AR           MIL

8 행이 선택되었습니다.


conn adminarmc/welcome1
set line 200

select * from handson.evaluate_t ;
EMPNO                                FST_EV SND_EV FIN_EV EMP_SOSOK_CD EMP_SB_CD
------------------------------------ ------ ------ ------ ------------ ------------------
21-10044                             3      3      2      AR           MC
21-10106                             1      5             AR           MC


0. clear example

conn appuser/welcome1

drop package DATAZONE_DRV_CTX_PKG;
drop function VPD_FUNCTION_SOSOK_GROUP;
drop function VPD_FUNCTION_SB_GROUP;
drop package DATAZONE_CTX_PKG;

drop trigger SET_DATAZONE_CTX_TRIG;
drop trigger SET_DATAZONE_DRV_CTX_TRIG;

exec DBMS_RLS.DISABLE_GROUPED_POLICY('HANDSON','EVALUATE_T','SOSOK_GROUP','FILTER_SOSOK_POLICY');
exec DBMS_RLS.DISABLE_GROUPED_POLICY('HANDSON','EVALUATE_T','SB_GROUP','FILTER_SB_POLICY');

exec DBMS_RLS.DROP_GROUPED_POLICY('HANDSON', 'EVALUATE_T', 'SOSOK_GROUP','FILTER_SOSOK_POLICY') ;
exec DBMS_RLS.DROP_GROUPED_POLICY('HANDSON', 'EVALUATE_T', 'SB_GROUP','FILTER_SB_POLICY') ;

exec DBMS_RLS.DELETE_POLICY_GROUP('HANDSON','EVALUATE_T','SOSOK_GROUP');
exec DBMS_RLS.DELETE_POLICY_GROUP('HANDSON','EVALUATE_T','SB_GROUP');

exec DBMS_RLS.DROP_POLICY_CONTEXT('handson','evaluate_t','datazone_drv_ctx','policy_group');

conn / as sysdba
sleep 2
drop context datazone_ctx;
drop context datazone_drv_ctx;
drop user handson cascade;
drop user ADMINAR cascade;
drop user ADMINARMC cascade;
drop user ADMINARMIL cascade;
drop user ADMINNV cascade;
drop user ADMINAF cascade;

col package format a20
col function format a24
col policy_group format a24
column object_name format a24
col policy_type format a24
col policy_name format a20


select object_name,policy_group, policy_name, policy_type, function, package from user_policies; 

select object_owner,object_name,policy_group, policy_name, policy_type, function, package from dba_policies;