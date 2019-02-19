#!/bin/sh

# Exit script if there are no files to convert
if [ -z "$(ls -A ./to_convert_files)" ]; then
	echo "Empty"
	exit 0
fi


ARCHIVE=./converted_archive/
CONVERT_DIR=./converted_files/
LOG=./edi-convert.log
TIMESTAMP=$(date +%Y%m%d-%H%M) # For the logfile
DATE=$(date +%Y%m%d) # For naming the .csv files

echo $TIMESTAMP >> $LOG

increment_filename(){
		
	archive=$1	
	file=$(echo $2 | tr -d '.csv') 
	
	if [ -e $archive${file}.csv ]
	then #increment filename if already in archive
		
		i=2

		echo "File ${archive}${file}.csv exists, incrementing filename..." >> $LOG

		# 002-009	
		while [ $i -le 99 ] 
		do
			if [ -e ${archive}${file}_${i}.csv ]; then
				echo "File ${file}_$i already exists, incrementing filename..." >> $LOG
				i=$((i+1))
			else
				# save file
				file=$(echo "${file}_${i}")
				echo "Saving file as ${file}.csv" >> $LOG
				break
			fi		
		done

	else
		# save file
		echo "Saving file as ${file}.csv" >> $LOG
	fi
	
	echo ${file}.csv # Final output new incremented name of the file
}

for filename in ./to_convert_files/*/*
do

	echo "Processing $filename ..." >> $LOG
	
	#date=$(stat -c %x $filename | cut -c1-10 | tr -d -)
	date=$(grep "DTM+" $filename | cut -d':' -f 2)

	# Determine PRICAT / DESADV
	ttype=$(grep "UNH+" $filename | cut -d'+' -f 3 | cut -d':' -f 1 )

	printf "\n$filename\n"; # Just for debugging



	# ================================
	# =========== PRICAT =============
	# ================================
	if [ $ttype == "PRICAT" ]
	then

		# Delivery note information
		sender=$(grep "NAD+SU" $filename | cut -d'+' -f 3 | cut -d':' -f 1 )
		recipient=$(grep "NAD+BY" $filename | cut -d'+' -f 3 | cut -d':' -f 1 )
		reference=$(grep "UNT+" $filename | cut -d'+' -f 3 | sed "s/'//" | tr -d '\r' )
		date_of_document=$(grep "DTM+" $filename | cut -d':' -f 2 )
		gln_supplier=$(grep "NAD+SU" $filename | cut -d'+' -f 3 | cut -d':' -f 1 )
		gln_customer=$(grep "NAD+BY" $filename | cut -d'+' -f 3 | cut -d':' -f 1 )
		currency=$(grep "CUX+" $filename | cut -d':' -f 2 )
		category=$(grep "RFF+ON" $filename | cut -d':' -f 2 | sed "s/'//" )

		# Create Delivery Note
		#new_delivery_note="DELIVERY_NOTE_${ttype}_${gln_supplier}.csv"
		#touch ${CONVERT_DIR}${new_delivery_note}
		#delivery_note_header="sender,recipient,reference,type,date_of_document,gin_supplier,gin_customer,currency"
		#delivery_note_row="${sender},${recipient},${reference},${ttype},${date_of_document},${sender},${recipient},${currency}"
		#echo $delivery_note_header >> ${CONVERT_DIR}${new_delivery_note}
		#echo $delivery_note_row >>${CONVERT_DIR} ${new_delivery_note}

		# Create new filename
		new_file="${DATE}_${ttype}_${gln_supplier}.csv"

		# Increment filename if already in archive
		new_file=$(increment_filename ${ARCHIVE}Pricat/ $new_file)
		echo "(Incremented) New file = $new_file"

		# Create .csv
		touch $new_file
		
		# Add PRICAT header
		pricat_header="ean,product_group,item_number,product_group_vendor,color_name,color_number,size,product_group_name,item_name,min_order_volume,season,purchase_price,recommended_price"
		echo $pricat_header >> ${CONVERT_DIR}${new_file}

		while read line 
		do
			# ----- EAN ------
			if echo $line | grep -q "LIN+"; then # -q option to suppress output
				new_line=$(printf $line | cut -d'+' -f 4 | cut -d':' -f 1) # Start new row for .csv

			# ----- PRODUCT GROUP / ITEM NUMBER ------
			elif echo $line | grep -q "PIA+5"; then
				add_line=$(printf $line | cut -d'+' -f 3 | cut -d'-' -f 1)
				new_line="${new_line},${add_line}"
				add_line=$(printf $line | cut -d'-' -f 2 | cut -d':' -f 1)
				new_line="${new_line},${add_line}"

			# ----- PRODUCT GROUP VENDOR ------
			elif echo $line | grep -q "PIA+1"; then
				add_line=$(printf $line | cut -d'+' -f 3 | cut -d':' -f 1)
				new_line="${new_line},${add_line}"

			# ----- COLOR NAME ------
			elif echo $line | grep -q "IMD+F+35"; then
				add_line=$(echo -n $line | cut -d':' -f 4 | sed "s/'//" | tr -d '\r')
				new_line="${new_line},${add_line}"

			# ----- COLOR NUMBER ------
			elif echo $line | grep -q "IMD+C+35+"; then
			 	add_line=$(printf $line | cut -d'+' -f 3 | cut -d':' -f 1)
			 	new_line="${new_line},${add_line}"

			# ----- SIZE ------
			elif echo $line | grep -q "IMD+C+98+"; then
				add_line=$(printf $line | cut -d'+' -f 3 | cut -d':' -f 1)
				new_line="${new_line},${add_line}"

			# ----- PRODUCT GROUP NAME ------
			elif echo $line | grep -q "IMD+F+TPE+"; then
				add_line=$(echo -n $line | cut -d':' -f 4 | sed "s/'//" | tr -d '\r')
				new_line="${new_line},${add_line}"

			# ----- ITEM NAME ------
			elif echo $line | grep -q "IMD+F+ANM+"; then
				add_line=$(echo -n $line | cut -d':' -f 4 | sed "s/'//" | tr -d '\r')
				compare=$(echo -n $add_line | sed "s/,//") # Remove comma and compare to that string
				if [[ $add_line != $compare ]]; then
					add_line="\"${add_line}\"" # Add double quotes if string has commas
				fi
				new_line="${new_line},${add_line}"

			# ----- MIN ORDER VOLUME ------
			elif echo $line | grep -q "QTY+53:"; then
				add_line=$(printf $line | cut -d':' -f 3 | sed "s/'//" | tr -d '\r')
				new_line="${new_line},${add_line}"

			# ----- SEASON ------
			elif echo $line | grep -q "FTX+PRD+1+SEA"; then
				LANG=C # Für Umlaute äöü etc
				add_line=$(echo -n $line | cut -d'+' -f 5 | sed "s/'//" | tr -d '\r')
				new_line="${new_line},${add_line}"

			# ----- PURCHASE PRICE ------
			elif echo $line | grep -q "PRI+AAA:"; then
				add_line=$(echo $line | cut -d':' -f 2 | cut -d':' -f 1)
				new_line="${new_line},${add_line}"

			# ----- RECOMMENDED PRICE ------
			elif echo $line | grep -q "PRI+AAE:"; then
				add_line=$(echo $line | cut -d':' -f 2 | cut -d':' -f 1) 
				new_line="${new_line},${add_line}"
				echo $new_line >> ${CONVERT_DIR}${new_file}
			fi

		done < $filename

		# Archive file
		cp ${CONVERT_DIR}${new_file} ./converted_archive/Pricat/$new_file

		# Transfer file to pps-st-10
		sshpass -f "./scp_pass.txt" scp ${CONVERT_DIR}${new_file} admin@pps-st-10.pps.intern:/volume1/daten/Operations/HFG/Delivery/Test/Pricat/	


	# ================================
	# =========== DESADV =============
	# ================================
	elif [ $ttype == "DESADV" ]
	then

		# Delivery note information
		sender=$(grep "UNB+UNOC" $filename | cut -d'+' -f 3 | cut -d':' -f 1 )
		recipient=$(grep "UNB+UNOC" $filename | cut -d'+' -f 4 | cut -d':' -f 1 )
		reference=$(grep "UNT+" $filename | cut -d'+' -f 3 | sed "s/'//" | tr -d '\r' )
		date_of_document=$(grep "DTM+" $filename | cut -d':' -f 2 )
		order_number=$(grep "RFF+VN" $filename | cut -d':' -f 2 | sed "s/'//" | tr -d '\r' )
		gln_customer=$(grep "NAD+BY" $filename | cut -d'+' -f 3 | cut -d':' -f 1 )
		gln_final_goods_recipient=$(grep "NAD+UC" $filename | cut -d'+' -f 3 | cut -d':' -f 1 )
		gln_supplier=$(grep "NAD+SU" $filename | cut -d'+' -f 3 | cut -d':' -f 1 )
		category=$(grep "RFF+ON" $filename | cut -d':' -f 2 | sed "s/'//" )

		# Create Delivery Note
		#new_delivery_note="./DELIVERY_NOTE_${ttype}_${gln_supplier}_${order_number}.csv"
		#touch $new_delivery_note
		#delivery_note_header="sender,recipient,reference,type,date_of_document,order_number,gln_customer,gln_final_goods_recipient,gln_supplier"
		#delivery_note_row="${sender},${recipient},${reference},${ttype},${date_of_document},${order_number},${gln_customer},${gln_final_goods_recipient},${gln_supplier}"
		#echo $delivery_note_header >> $new_delivery_note
		#echo $delivery_note_row >> $new_delivery_note

		# Create new filename
		new_file="${DATE}_${ttype}_${gln_supplier}_${order_number}.csv"

		# Increment filename if already in archive
		new_file=$(increment_filename ${ARCHIVE}Desadv/ $new_file)
		echo "(Incremented) New file = $new_file"

		# Create .csv
		touch ${CONVERT_DIR}${new_file}

		# Add DESADVD header
		desadv_header="ean,delivery_quantity,category"
		echo $desadv_header >> ${CONVERT_DIR}${new_file}

		while read line 
		do
			# ----- EAN ------
			if echo $line | grep -q "LIN+"; then # -q option to suppress output
				new_line=$(printf $line | cut -d'+' -f 4 | cut -d':' -f 1) # Start new row for .csv

			# ----- DELIVERY QUANTITY + CATEGORY  ------
			elif echo $line | grep -q "QTY+"; then
				add_line=$(printf $line | cut -d':' -f 2 | cut -d':' -f 1)
				new_line="${new_line},${add_line},${category}"
				echo $new_line >> ${CONVERT_DIR}${new_file}
			fi


		done < $filename

		# Archive file
		cp ${CONVERT_DIR}${new_file} ./converted_archive/Desadv/$new_file
		
		# Transfer to pps-st-10
		sshpass -f "./scp_pass.txt" scp ${CONVERT_DIR}${new_file} admin@pps-st-10.pps.intern:/volume1/daten/Operations/HFG/Delivery/Test/Desadv/

	fi

done

echo "Removing files from ./to_convert_files/ and $CONVERT_DIR ..." >> $LOG
rm -rf ./to_convert_files/*
rm $CONVERT_DIR*

printf "Done!\n\n" >> $LOG


exit 0
