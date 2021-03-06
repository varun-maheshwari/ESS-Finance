create or replace procedure     update_revenue_test(comp_code varchar2,region_code varchar2,v_mon varchar2,v_year number) is
cr_amt    number;
dr_amt    number;
net_val   number;
reg_curr  number;
reg_curr1 number;
conv_fact number;
cnt       number;
bs_curr   number;
inr_to_t  number(26,6);
op        varchar2(1);


freezed_flg number;
var_region varchar(50);

cursor period is
    select to_char(add_months(to_date('01-jan-'||v_year),l-1),'MON') mon,
           add_months(to_date('01-jan-'||v_year),l-1) n_mon
    from (select level l from dual connect by level <= 12)
    where  to_char(add_months(to_date('01-jan-'||v_year),l-1),'mm') like nvl(v_mon,'%');
    
cursor cust is
    select a.nu_customer_code,  d.coa_id nu_account_code, EBIZ_7_REG_CODE vc_region_code
    from makess.mst_customer@ebizdbl1 a, app.app$eo b, fin.fin$acc$na c, fin.fin$coa d,
    (select distinct cc_cld_id, cc_sloc_id, cc_ho_org_id, cc_txn_id, cc_ccid_lvl1 from fin.fin$coa$cost$center)
    e, mst_reg_code f
    where a.vc_comp_code = comp_code
    and b.eo_type = 68
    and to_number(b.eo_leg_code) = a.nu_customer_code
    and b.eo_cld_id = c.acc_cld_id
    and b.eo_ho_org_id = c.ho_org_id
    and b.eo_type = c.acc_type
    and b.eo_id = c.acc_type_id
    and c.ho_org_id = d.coa_ho_org_id
    and c.acc_id = d.coa_acc_id
    and d.coa_cld_id = e.cc_cld_id
    and d.coa_sloc_id = e.cc_sloc_id
    and d.coa_ho_org_id = e.cc_ho_org_id
    and d.coa_id = e.cc_txn_id
    and e.cc_ccid_lvl1 = f.EBIZ_10_REG_CODE
    AND F.ORG_ID = comp_code
    and f.EBIZ_7_REG_CODE like nvl(region_code||'%','%')
    and nvl(b.eo_actv, 'N') = 'Y'
--    and d.coa_id = 987
       UNION
        select a.nu_prospect_code nu_customer_code,  -1 nu_account_code, VC_PROSPECT_REGION_CODE vc_region_code
    from ebiz.mst_prospect@ebizdbl1 a
    where a.vc_comp_code = comp_code
    and a.VC_PROSPECT_REGION_CODE like nvl(region_code||'%','%')
    and a.nu_customer_code is null
    AND a.VC_PROSPECT_REGION_CODE NOT IN ('J038', 'J035', 'J033', 'J020')
    ;
 
cursor target is
    select a.nu_customer_code, a.vc_customer_name vc_customer_name, b.revenue rev_target, b.collection collec_target, e.coa_id coa_id
    from makess.mst_customer@ebizdbl1 a
    join app.app$eo c on(c.eo_leg_code = to_char(a.nu_customer_code))
    join fin.fin$acc$na d on(d.acc_type_id = c.eo_id and d.acc_type = c.eo_type)
    join fin.fin$coa e on(e.coa_acc_id = d.acc_id)
    
    inner join (SELECT SUM(DECODE(vc_type_code, 1, decode(v_mon, '01', nu_jan, '02', nu_feb, '03', nu_mar, '04', nu_apr, '05', nu_may, '06', nu_jun, '07', nu_jul, '08', nu_aug, '09', nu_sep, '10', nu_oct, '11', nu_nov, '12', nu_dec),0)) revenue,
    SUM(DECODE(vc_type_code, 3, decode(v_mon, '01', nu_jan, '02', nu_feb, '03', nu_mar, '04', nu_apr, '05', nu_may, '06', nu_jun, '07', nu_jul, '08', nu_aug, '09', nu_sep, '10', nu_oct, '11', nu_nov, '12', nu_dec),0)) collection,
    a.vc_project_code
    FROM ebiz.roll_annual_proj@ebizdbl1 a
    WHERE a.nu_year = v_year
    AND a.vc_type_code IN ('1', '3')
    AND VC_PROJECT_STATUS = 'E'
    GROUP BY a.vc_project_code ) b on ((b.vc_project_code = a.nu_customer_code) and a.vc_comp_code = '01')
--    where a.nu_customer_code is not null
union
    select a.nu_prospect_code nu_customer_code, a.vc_prospect_name vc_customer_name, b.revenue rev_target, b.collection collec_target , -1 coa_id
    from ebiz.mst_prospect@ebizdbl1 a 
    inner join (SELECT SUM(DECODE(vc_type_code, 1, decode(v_mon, '01', nu_jan, '02', nu_feb, '03', nu_mar, '04', nu_apr, '05', nu_may, '06', nu_jun, '07', nu_jul, '08', nu_aug, '09', nu_sep, '10', nu_oct, '11', nu_nov, '12', nu_dec),0)) revenue,
    SUM(DECODE(vc_type_code, 3, decode(v_mon, '01', nu_jan, '02', nu_feb, '03', nu_mar, '04', nu_apr, '05', nu_may, '06', nu_jun, '07', nu_jul, '08', nu_aug, '09', nu_sep, '10', nu_oct, '11', nu_nov, '12', nu_dec),0)) collection,
    a.vc_project_code
    FROM ebiz.roll_annual_proj@ebizdbl1 a
    WHERE a.nu_year = v_year
    AND a.vc_type_code   IN ('1', '3')
    AND VC_PROJECT_STATUS = 'N'
    GROUP BY a.vc_project_code) b on (b.vc_project_code = a.nu_prospect_code and a.vc_comp_code = '01')
where a.nu_customer_code is null
union
select a.nu_customer_code, a.vc_customer_name vc_customer_name, b.revenue rev_target, b.collection collec_target ,e.coa_id coa_id
    from makess.mst_customer@ebizdbl1 a
    join app.app$eo c on(c.eo_leg_code = to_char(a.nu_customer_code))
    join fin.fin$acc$na d on(d.acc_type_id = c.eo_id and d.acc_type = c.eo_type)
    join fin.fin$coa e on(e.coa_acc_id = d.acc_id)
    inner join ebiz.mst_prospect@ebizdbl1 f on (a.nu_customer_code = f.nu_customer_code)
    inner join (select sum(decode(vc_type_code, 1, decode(v_mon, '01', nu_jan, '02', nu_feb, '03', nu_mar, '04', nu_apr, '05', nu_may, '06', nu_jun, '07', nu_jul, '08', nu_aug, '09', nu_sep, '10', nu_oct, '11', nu_nov, '12', nu_dec),0)) revenue, sum(decode(vc_type_code, 3, decode(v_mon, '01', nu_jan, '02', nu_feb, '03', nu_mar, '04', nu_apr, '05', nu_may, '06', nu_jun, '07', nu_jul, '08', nu_aug, '09', nu_sep, '10', nu_oct, '11', nu_nov, '12', nu_dec),0)) collection, a.vc_project_code from ebiz.roll_annual_proj@ebizdbl1 a where a.nu_year = v_year and a.vc_type_code in ('1', '3') AND VC_PROJECT_STATUS = 'N' group by a.vc_project_code) b on ((b.vc_project_code = f.NU_PROSPECT_CODE) and a.vc_comp_code = '01')
    where a.nu_customer_code is not null
;
    
cursor tran(mon varchar2, acc_code number) is
    select GL_ORG_ID vc_comp_code, GL_VOU_ID vc_voucher_no, trunc(GL_VOU_DT) dt_voucher_date,
    0 new_vc_pur_type, GL_CURR_ID_SP nu_currency_code,GL_COA_ID
    From  Fin.GL_LINES A, GL$COST$CENTER B 
    Where 
    A.GL_CLD_ID = B.CC_CLD_ID 
    AND A.GL_SLOC_ID = B.CC_SLOC_ID 
    AND A.GL_HO_ORG_ID = B.CC_HO_ORG_ID 
    AND A.GL_ORG_ID = B.CC_ORG_ID
    AND A.GL_VOU_ID = B.CC_TXN_ID 
    AND A.CC_ID = B.CC_ID 
    and a.gl_coa_id = acc_code
    and nvl(a.GL_AMT_SP,0) <> 0 
    and to_number(to_char(a.GL_VOU_DT,'rrrr')) = v_year 
    and to_char(a.GL_VOU_DT,'MON') = mon
    AND A.GL_TYPE_ID not in (2,3,4,5)
    and b.CC_CCID_LVL1 <> '0000.01.08.000A.00XR.00.1UTFpnvkO4'
    and b.CC_CCID_LVL2 <> '0008010300003'
    AND TRIM(B.CC_CCID_LVL3) not in ( 'ITM001', 'SLS.020')
--    and TRIM(B.CC_CCID_LVL3) = C.EBIZ_REG_CODE
--    AND SERVICE_ID <> '1003' AND C.TRANS_TYPE = 'R'
    ;
    
cursor tran_rev(mon varchar2,acc_code number) is
    select GL_ORG_ID vc_comp_code, GL_VOU_ID vc_voucher_no, trunc(GL_VOU_DT) dt_voucher_date,
    0 new_vc_pur_type, GL_CURR_ID_SP nu_currency_code,GL_COA_ID
    From  Fin.GL_LINES A, GL$COST$CENTER B
    Where 
    A.GL_CLD_ID = B.CC_CLD_ID 
    AND A.GL_SLOC_ID = B.CC_SLOC_ID 
    AND A.GL_HO_ORG_ID = B.CC_HO_ORG_ID 
    AND A.GL_ORG_ID = B.CC_ORG_ID
    AND A.GL_VOU_ID = B.CC_TXN_ID 
    AND A.CC_ID = B.CC_ID 
    AND a.GL_COA_ID = acc_code 
    and nvl(a.GL_AMT_SP,0) <> 0 
    and to_number(to_char(a.GL_VOU_DT,'rrrr')) = v_year 
    and to_char(a.GL_VOU_DT,'MON') = mon
    AND A.GL_TYPE_ID in (2,3,4,5,1)
--    and TRIM(B.CC_CCID_LVL3) = C.EBIZ_REG_CODE
    and b.CC_CCID_LVL1 <> '0000.01.08.000A.00XR.00.1UTFpnvkO4'
    and b.CC_CCID_LVL2 <> '0008010300003'
    AND TRIM(B.CC_CCID_LVL3) not in ('ITM001', 'SLS.020')
--    AND SERVICE_ID <> '3003' AND C.TRANS_TYPE = 'C'

      ;

begin

for i in period loop 
  begin
    select count(distinct is_freezed) into freezed_flg from TRGT$VS$ACTUAL
    where year = v_year and month = i.mon
    and is_freezed = 'Y';
    
    if freezed_flg > 0 then
      raise_application_error(-20011, 'Data has been freezed for given month. Cannot proceed!!');
    end if;
    
  end;
    update TRGT$VS$ACTUAL
    set REVENUE = 0
    where year = v_year
    and month = i.mon;
    
    update TRGT$VS$ACTUAL
    set collection = 0
    where year = v_year
    and month = i.mon;
    
    update TRGT$VS$ACTUAL set 
      TARGET_ROLLING_REVENUE = 0, TARGET_ROLLING_COLLECTION = 0
      where year = v_year
      and month = i.mon;
    
  for j in cust loop  
    
    select count(*)
    into   cnt 
    from   TRGT$VS$ACTUAL
    where  CUST_CODE = j.nu_customer_code
    and coa_id = j.nu_account_code
    and    year = v_year
    and    MONTH = i.mon
    and region = j.vc_region_code;
    
    if nvl(cnt,0) = 0 then
            begin
              insert into TRGT$VS$ACTUAL
              (REGION, CUST_CODE, YEAR, MONTH, TARGET_ACTUAL_REVENUE, TARGET_ROLLING_REVENUE, 
              TARGET_ACTUAL_COLLECTION, TARGET_ROLLING_COLLECTION, CURRENCY, COLLECTION, REVENUE, ACTIVITY_CODE, coa_id)
              values(j.vc_region_code, j.nu_customer_code, v_year, i.mon, 0, 0, 0, 0, 1, 0, 0, 0, j.nu_account_code);
            exception when others then
              raise_application_error(-20003,'Unable to insert in mst_actual!');
            end;          
    end if;
    
    net_val := 0;
         begin
            select distinct NU_CURRENCY_CODE
            into  reg_curr
            from ebiz.mst_target@ebizdbl1 a 
            where vc_comp_code = comp_code 
            and nu_year = v_year
            and VC_REGION_CODE = j.vc_region_code;
         exception 
         when no_data_found then
         SELECT REGION_CURR INTO reg_curr
         FROM MST_REG_CODE 
         WHERE EBIZ_7_REG_CODE = j.vc_region_code;
--         reg_curr := fn_coa_curr('0000', 1, '03', j.nu_account_code);
--           raise_application_error(-20001,'Unable to select region currency ! '||j.vc_region_code);
         when others then
           raise_application_error(-20001,'Unable to select region currency ! '||j.vc_region_code);
         end;
         
         reg_curr1 := reg_curr;
         reg_curr := FN_FIN_GET_CURR_ID_LEG(reg_curr);
         
         for k in tran(i.mon, j.nu_account_code) loop
          net_val :=0;
             Begin
                Select Sum(Decode(GL_AMT_TYP,'Cr',Decode(K.nu_currency_code,Reg_Curr,Nvl(GL_AMT_SP,0),Nvl(GL_AMT_BS,0)),0)) C_Amt,
                       SUM(decode(GL_AMT_TYP,'Dr',decode(k.nu_currency_code,reg_curr,nvl(GL_AMT_SP,0),nvl(GL_AMT_BS,0)),0)) d_amt  
                into    cr_amt,dr_amt          
                from  fin.GL_LINES a
                where a.GL_ORG_ID = k.vc_comp_code
                and   a.GL_COG_ID LIKE '3001%' and A.GL_VOU_ID = k.vc_voucher_no
                and trunc(GL_VOU_DT) = trunc(k.dt_voucher_date) ;
            exception when others then
             cr_amt := 0;
             dr_amt := 0;
            end;     
--IF j.nu_customer_code = 1169 THEN
--DBMS_OUTPUT.PUT_LINE('nu_currency_code = '|| K.nu_currency_code ||'Reg_Curr = ' || Reg_Curr || 'net val = ' || to_char(net_val) || 'vou no = ' ||k.vc_voucher_no);
--END IF;
             
             if k.vc_comp_code != '01' then
             begin
                select nu_conv_factor
                into   inr_to_t
                from   app.mst_monthly_curr_conv
                where  vc_comp_code = k.vc_comp_code
                and    vc_month     = to_char(i.n_mon,'mm')
                and    vc_year      = to_char(v_year);
                exception when others then
                raise_application_error(-20001,'Unable to select conversion from mst_monthly_curr_conv !');  
             end;
             else -- Rajender 01-Jul-2019
                          
             inr_to_t := 1;
             
             end if;
             
             if j.nu_account_code = 3592 then
              dbms_output.put_line('Reg curr :'||reg_curr||', nu_currency_code :'||k.nu_currency_code);
             end if;

             if nvl(reg_curr,0) = ltrim(rtrim(k.nu_currency_code)) then
                net_val := nvl(net_val,0)+nvl(cr_amt,0)-nvl(dr_amt,0);
             else
                begin
                  select nvl(nu_conv_factor,1)
                  into   conv_fact
                  from   finance.mst_essence_conv_factor@ebizdbl1 
                  where  vc_month = v_mon--to_char ( to_date(i.n_mon, 'dd-mon-yy'),'mm') 
                  and    nu_year  = v_year
                  and    nu_from_currency = 1
                  and    nu_to_currency   = 6;
                exception 
                when others then
                  raise_application_error(-20002,'Unable to select conversion factor !'||v_mon||' '||j.vc_region_code);
                end;
                cr_amt := round(nvl(cr_amt,0)*inr_to_t,2);
                dr_amt := round(nvl(dr_amt,0)*inr_to_t,2);
                net_val := nvl(net_val,0)+round(nvl(cr_amt,0)/conv_fact,2)-round(nvl(dr_amt,0)/conv_fact,2);
             end if;
        select count(*)
        into   cnt 
        from   TRGT$VS$ACTUAL
        where  CUST_CODE = j.nu_customer_code
        and coa_id = j.nu_account_code
        and    year = v_year
        and    MONTH = i.mon;

--IF j.nu_customer_code = 1169 THEN
--DBMS_OUTPUT.PUT_LINE('cr amt = '||to_char(nvl(cr_amt,0)) ||'conv_fact = ' || conv_fact || ' inr_to_t = ' || inr_to_t || ' net val = ' || to_char(net_val) || ' vou no = ' ||k.vc_voucher_no);
--END IF;
      if cnt > 1 then
        update TRGT$VS$ACTUAL
        set    REVENUE = nvl(REVENUE,0)+nvl(net_val,0)
        where  year      = v_year
        and    CUST_CODE = j.nu_customer_code                 
        and coa_id = j.nu_account_code
        and coa_id != -1
        and month = i.mon;
     else
             update TRGT$VS$ACTUAL
        set    REVENUE = nvl(REVENUE,0)+nvl(net_val,0)
        where  year      = v_year
        and    CUST_CODE = j.nu_customer_code                 
        and coa_id = j.nu_account_code
        and month = i.mon;
     end if;

       end loop;---end of tran
       
       
       net_val := 0;
         begin
            select distinct NU_CURRENCY_CODE
            into  reg_curr
            from ebiz.mst_target@ebizdbl1 a 
            where vc_comp_code = comp_code 
            and nu_year = v_year
            and VC_REGION_CODE = j.vc_region_code;
         exception 
         when no_data_found then
         SELECT REGION_CURR INTO reg_curr
         FROM MST_REG_CODE 
         WHERE EBIZ_7_REG_CODE = j.vc_region_code;
--         null;
         when others then
           raise_application_error(-20001,'Unable to select region currency ! '||j.vc_region_code);
         end;
         
         reg_curr1 := reg_curr;
         reg_curr := FN_FIN_GET_CURR_ID_LEG(reg_curr);
                         
         for k in tran_rev(i.mon,j.nu_account_code) loop
          net_val :=0;
             Begin
                Select Sum(Decode(GL_AMT_TYP,'Cr',Decode(K.nu_currency_code,Reg_Curr,Nvl(GL_AMT_SP,0),Nvl(GL_AMT_BS,0)),0)) C_Amt,
                       SUM(decode(GL_AMT_TYP,'Dr',decode(k.nu_currency_code,reg_curr,nvl(GL_AMT_SP,0),nvl(GL_AMT_BS,0)),0)) d_amt  
                into    cr_amt,dr_amt          
                from  fin.GL_LINES a
                where a.GL_ORG_ID = k.vc_comp_code
                and   a.GL_COA_ID = j.nu_account_code
                and A.GL_VOU_ID = k.vc_voucher_no
                and trunc(GL_VOU_DT) = trunc(k.dt_voucher_date) ;
            exception when others then
             cr_amt := 0;
             dr_amt := 0;
             end;
             
             bs_curr := app.fn_get_org_def_curr_bs1('0000', k.vc_comp_code);
             
             if k.vc_comp_code != '01' then
             begin
                select nu_conv_factor
                into   inr_to_t
                from   app.mst_monthly_curr_conv
                where  vc_comp_code = k.vc_comp_code
                and    vc_month     = to_char(i.n_mon,'mm')
                and    vc_year      = to_char(v_year);
                exception when others then
                raise_application_error(-20001,'Unable to select conversion from mst_monthly_curr_conv !'||sqlcode||' - '||sqlerrm||' - '||k.vc_comp_code||' - '||to_char(i.n_mon,'mm')||' - '||to_char(v_year));  
             end;
             
             else
             
             inr_to_t := 1;
             
             end if;
             
             if nvl(reg_curr,0) = ltrim(rtrim(k.nu_currency_code)) then
                net_val := nvl(net_val,0)+nvl(cr_amt,0)-nvl(dr_amt,0);
             else
                begin
                  select nvl(nu_conv_factor,1)
                  into   conv_fact
                  from   finance.mst_essence_conv_factor@ebizdbl1 
                  where  vc_month = v_mon--to_char ( to_date(i.n_mon, 'dd-mon-yy'),'mm') 
                  and    nu_year  = v_year
                  and    nu_from_currency = 1
                  and    nu_to_currency   = 6;
--             if j.nu_customer_code = 1046 then
--         DBMS_OUTPUT.PUT_LINE('Cr Amt = '||to_char(cr_amt)||', Dr Amt = '||to_char(dr_amt)||', Conv fctr = '||to_char(conv_fact)||', Inr to T = '||to_char(inr_to_t)||', v_mon = '||to_char(i.n_mon,'mm')||', comp code = '||k.vc_comp_code);
--         end if;
--                exception when others then
--                  raise_application_error(-20002,'Unable to select conversion factor !'||nvl(reg_curr1,0)||' '||ltrim(rtrim(k.nu_currency_code))||'  '||v_mon||k.vc_comp_code||'   '||k.vc_voucher_no);
                end;
                cr_amt := round(nvl(cr_amt,0)*inr_to_t,2);
                dr_amt := round(nvl(dr_amt,0)*inr_to_t,2);
                net_val := nvl(net_val,0)+round(nvl(cr_amt,0)/conv_fact,2)-round(nvl(dr_amt,0)/conv_fact,2);
             end if;

        select count(*)
        into   cnt 
        from   TRGT$VS$ACTUAL
        where  CUST_CODE = j.nu_customer_code
        and coa_id = j.nu_account_code
        and    year = v_year
        and    MONTH = i.mon;

      if cnt > 1 then
        update TRGT$VS$ACTUAL
        set    COLLECTION = nvl(COLLECTION,0)+nvl(net_val,0)
        where  year      = v_year
        and    CUST_CODE = j.nu_customer_code                 
        and coa_id = j.nu_account_code
        and coa_id != -1
        and month = i.mon;
     else
        update TRGT$VS$ACTUAL
        set    COLLECTION = nvl(COLLECTION,0)+nvl(net_val,0)
        where  year      = v_year
        and    CUST_CODE = j.nu_customer_code                 
        and coa_id = j.nu_account_code
        and month = i.mon;
     end if;     
      end loop;---end of tran_rev
         
   end loop;----end of cust
   
   for m in target loop
        select count(*)
        into   cnt 
        from   TRGT$VS$ACTUAL
        where  CUST_CODE = m.nu_customer_code
        and coa_id = m.coa_id
        and    year = v_year
        and    MONTH = i.mon;
      update TRGT$VS$ACTUAL set 
      TARGET_ROLLING_REVENUE = m.REV_TARGET, TARGET_ROLLING_COLLECTION = m.COLLEC_TARGET
      where
      cust_code = m.NU_CUSTOMER_CODE
      and coa_id = m.coa_id
      and year = v_year
      and month = i.mon;
   end loop;  ---end target
   
   delete from trgt$vs$actual where year = v_year and month = i.mon and 
(TARGET_ACTUAL_REVENUE = 0 and TARGET_ROLLING_REVENUE = 0 and TARGET_ACTUAL_COLLECTION = 0 and TARGET_ROLLING_COLLECTION = 0 and
COLLECTION = 0 and REVENUE = 0) and cust_code = 304 and coa_id = -1;
   
  end loop;---end of period
  
  
  
  op := FN_UPD_REG_SUMM(v_mon, v_year);
    
  commit;
end;