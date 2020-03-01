Remove-Item -LiteralPath "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\Bookie" -Force -Recurse
mkdir "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\Bookie" 
copy-item ..\*.lua -destination "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\Bookie" 
copy-item ..\*.xml -destination "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\Bookie" 
copy-item ..\Bookie_retail.toc -destination "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\Bookie\Bookie.toc" 
copy-item -path ..\libs -destination "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\Bookie\libs" -recurse -force
copy-item -path ..\core -destination "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\Bookie\core" -recurse -force