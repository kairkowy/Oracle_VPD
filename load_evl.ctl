load data
infile  './evaluate_dataset.dat'
into table evaluate_t
fields terminated by ','
(empno,
fst_ev_grade,
snd_ev_grade,
fin_ev_grade,
emp_sosok_cd,
emp_sb_cd
) 

