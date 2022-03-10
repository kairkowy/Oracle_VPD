** 오라클 Secirity-VPD 기본 기능 실습 예제

// 실습을 위한 사용자 계정은 별도 자료 자료를 참조하세요.

2.1 사용자 세션 기반의 Application Context 생성

Oracle Database는 “Application Context”를 사용하여 데이터베이스 및 비데이터베이스 사용자에 대한 정보를 얻을 수 있습니다. 이 정보를 이용하여 Application 및 SQL*PLUS와 같은 DB 액세스 툴을 통해 데이터에 액세스 하는 것을 허용하거나 통제가 가능합니다.
아래와 같이 Application context 를 위한 작업을 수행합니다. 
Application 계정이 DB에 로그인 할 때 Application Context에 사용할 사용자 세션 정보를 강제 적용하도록 합니다. 이 정보는 Application 계정이 수정을 못하도록 DB 커널에서 강제됩니다.

conn appuser/Welcome1@pdb

col dbuser format a20
select SYS_CONTEXT('USERENV', 'SESSION_USER') dbuser from dual;

DBUSER
--------------------
APPUSER

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

--GRANT EXECUTE ON datazone_ctx_pkg TO adminar;
--GRANT EXECUTE ON datazone_ctx_pkg TO adminarmil;
--GRANT EXECUTE ON datazone_ctx_pkg TO adminarmc;
--GRANT EXECUTE ON datazone_ctx_pkg TO adminnv;
--GRANT EXECUTE ON datazone_ctx_pkg TO adminaf;

CREATE or REPLACE TRIGGER set_datazone_ctx_trig AFTER LOGON ON DATABASE
 BEGIN
    appuser.datazone_ctx_pkg.set_datazone;
  EXCEPTION
  WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR(
    -20000, 'Trigger handson.datazone_ctx_pkg.set_datazone violation. Login denied.');
 END;
/

Appplication context 정보 테스트
conn adminar/Welcome1@pdb

SELECT SYS_CONTEXT('datazone_ctx', 'data_zone') DBzone FROM DUAL;

DBZONE
--------------------------------------------------------------------------------
AR

2.2 Policy Function 및 Policy 생성

VPD의 핵심 컴포넌트는 Policy Function과 Ploicy 입니다. Polic Function은 동적 WHEWE 절을 강제 적용하도록 제어하는 함수이며, 
Policy는 Policy Function을 타겟 객체에 적용(attathc)하기 위한 security 기능입니다. 


2.3 Function 생성
conn appuser/appuser

==============================================================

CREATE OR REPLACE FUNCTION vpd_get_datazone(
  schema_p   IN VARCHAR2,
  table_p    IN VARCHAR2)
 RETURN VARCHAR2
 AS
  users_pred VARCHAR2 (400);
 BEGIN
 	  users_pred := 'emp_sosok_cd = SYS_CONTEXT(''datazone_ctx'', ''data_zone'')'; 
 RETURN users_pred;
END;
/

=================================

2.4 Policy 생성

Begin 
dbms_rls.add_policy(
object_schema => 'HANDSON',
object_name => 'EVALUATE_T',
policy_name =>'EVAL_DATAZONE_POLICY',
Function_schema => 'APPUSER',
policy_function =>'VPD_GET_DATAZONE',
Statement_types => 'SELECT,UPDATE,INSERT,DELETE',
policy_type => DBMS_RLS.CONTEXT_SENSITIVE,
namespace => 'DATAZONE_CTX',
attribute=>'DATA_ZONE',
update_check => TRUE, 
enable => TRUE);
end;
/



2.5 VPD Policy 테스트(컬럼-열 추출 제어 policy 테스트)

conn adminar / Welcome1@pdb
SELECT SYS_CONTEXT('datazone_ctx', 'data_zone') DATAZONE FROM DUAL;

DATAZONE
--------------------------------------------------------------------------------
AR

select * from handson.evaluate_t;

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

conn adminaf/Welcome1@pdb

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


conn adminarmil/Welcome1@pdb

select * from handson.evaluate_t;

선택된 레코드가 없습니다.

column datazone format a20

SELECT SYS_CONTEXT('datazone_ctx', 'data_zone') DATAZONE FROM DUAL;
DATAZONE
--------------------
ARMIL



2.6 컬럼 Null Masking Policy 테스트

conn appuser/Welcome1@pdb

exec DBMS_RLS.DROP_POLICY('handson', 'evaluate_t', 'eval_datazone_policy'); 


Begin 
dbms_rls.add_policy(
object_schema => 'HANDSON',
object_name => 'EVALUATE_T',
policy_name =>'EVAL_MASKING_POLICY',
Function_schema => 'APPUSER',
policy_function =>'VPD_GET_DATAZONE',
policy_type => DBMS_RLS.CONTEXT_SENSITIVE,
namespace => 'DATAZONE_CTX',
attribute=>'DATA_ZONE',
update_check => TRUE, 
enable =>TRUE,
sec_relevant_cols => 'FST_EV_GRADE,SND_EV_GRADE,FIN_EV_GRADE',
sec_relevant_cols_opt => DBMS_RLS.ALL_ROWS);
end;
/

select * from handson.evaluate_t;

EMPNO                                FST_EV SND_EV FIN_EV EMP_SOSOK_CD EMP_SB_CD
------------------------------------ ------ ------ ------ ------------ ------------------
21-10011                                                  AR           MIL
21-10102                                                  AR           MIL
21-10203                                                  AR           MIL
21-10044                                                  AR           MC
21-15005                                                  AR           MIL
21-10106                                                  AR           MC
21-10307                                                  AR           MIL
21-10038                                                  AR           MIL
21-10009                                                  AR           MIL
21-11010                                                  AR           MIL
21-20301                                                  NV           MIL
21-20002                                                  NV           MIL
21-20343                                                  NV           MIL
21-20104                                                  NV           MIL
21-20235                                                  NV           MC
21-21106                                                  NV           MIL
21-20207                                                  NV           MIL
21-21008                                                  NV           MC
21-20459                                                  NV           MIL
21-20210                                                  NV           MIL
21-30001                                                  AF           MIL
21-31102                                                  AF           MIL
21-33203                                                  AF           MIL
21-30004                                                  AF           MC
21-30905                                                  AF           MIL
21-30806                                                  AF           MIL
21-30047                                                  AF           MC
21-30078                                                  AF           MIL
21-30309                                                  AF           MIL
21-30010                                                  AF           MIL

30 행이 선택되었습니다.


0. 실습 정리
conn appuser/Welcome1@pdb

drop package datazone_ctx_pkg;
drop function vpd_get_datazone;
drop trigger set_datazone_ctx_trig;
exec DBMS_RLS.DROP_POLICY('handson', 'evaluate_t', 'eval_datazone_policy'); 
exec DBMS_RLS.DROP_POLICY('handson', 'evaluate_t', 'EVAL_MASKING_POLICY'); 

conn / as sysdba
drop context datazone_ctx;
-- drop user handson cascade;
-- drop userADMINAR cascade;
-- drop user ADMINARMC cascade;
-- drop user ADMINARNIL cascade;
-- drop user ADMINNV cascade;
-- drop user ADMINAF cascade;
