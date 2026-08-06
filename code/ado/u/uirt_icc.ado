*uirt_icc.ado 
*ver 1.1
*2022.01.24
*everythingthatcounts@gmail.com

capture prog drop uirt_icc
program define uirt_icc
version 10
syntax [varlist] [, bins(numlist integer max=1 >=1) Format(str) CLeargraphs NOObs pv pvbin(numlist max=1 >=100 <=100000) Colors(str) tw(str asis) PREFix(str) SUFfix(str)] 
	
	if("`e(cmd)'" != "uirt"){
		error 301
	}
	else{
	
		if("`0'"==""){
			local postest="icc(*)"	
		}
		else{
			local postest="icc("+`"`0'"'+")"
		}
	
		m: backup_e=st_tempname()
		m: stata("qui estimates store "+backup_e)
		
		m: st_local("errcode",strofreal(_stata("`e(cmdstrip)' " + `"`postest'"' + " fix(prev used) err(stored) nit(0) tr(0) not noh")))
		if(`errcode'){
			exit `errcode'
		}
		
		m: stata("qui estimates restore "+backup_e)
		m: stata("qui estimates drop "+backup_e)
	
	}
	
end

