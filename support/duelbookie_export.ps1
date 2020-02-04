Remove-Item -LiteralPath "C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\DuelBookie" -Force -Recurse
mkdir "C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\DuelBookie" 
copy-item ..\*.lua -destination "C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\DuelBookie" 
copy-item ..\*.xml -destination "C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\DuelBookie" 
copy-item ..\*.toc -destination "C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\DuelBookie" 
copy-item -path ..\libs -destination "C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\DuelBookie\libs" -recurse -force
copy-item -path ..\core -destination "C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\DuelBookie\core" -recurse -force