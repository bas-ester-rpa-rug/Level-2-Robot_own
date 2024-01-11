*** Comments ***
#    THE RULES to which to robot much oblige:

#    1. Only the robot is allowed to get the orders file. You may not save the file manually on your computer. 
#    2. The robot should save each order HTML receipt as a PDF file. 
#    3. The robot should save a screenshot of each of the ordered robots. 
#    4. The robot should embed the screenshot of the robot to the PDF receipt. 
#    5. The robot should create a ZIP archive of the PDF receipts (one zip archive that contains all the PDF files). Store the archive in the output directory. 
#    6. The robot should complete all the orders even when there are technical failures with the robot order website. 
#    7. The robot should read some data from a local vault. In this case, do not store sensitive data such as credentials in the vault. The purpose is to verify that you know how to use the vault. 
#    8. The robot should use an assistant to ask some input from the human user, and then use that input some way. 
#    9. The robot should be available in public GitHub repository. 
#    10. Store the local vault file in the robot project repository so that it does not require manual setup. 
#    11. It should be possible to get the robot from the public GitHub repository and run it without manual setup. 



*** Settings ***
Documentation       The rules of the things the robot does are posted above

Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             RPA.PDF
Library             RPA.HTTP
Library             RPA.Tables
Library             OperatingSystem
Library             DateTime
Library             Dialogs
Library             Screenshot
Library             RPA.Archive
Library             RPA.Robocorp.Vault
Library    RPA.Excel.Application
Library    RPA.RobotLogListener

*** Variables ***
#the urls we use to get the csv file and the website is more neatly placed here
${url}        https://robotsparebinindustries.com/#/robot-order
${csv_url}    https://robotsparebinindustries.com/orders.csv

#directories where we post our receipts and screenshots
${receipt_directory}=       ${OUTPUT_DIR}${/}receipts/
${screenshot_directory}=         ${OUTPUT_DIR}${/}screenshots/   
${zip_directory}=           ${OUTPUT_DIR}${/}zip/

*** Tasks ***
Order Robots from RobotSpareBin Industries Inc.
    Stating who wrote this from vault

    Directory Cleanup

    Download csv file
    Open the robot order website

    Fill out the form completely

    Make the zip file

    Close Browser 
*** Keywords ***
Stating who wrote this from vault 
    Log To Console          Getting Secret from our Vault
    ${secret}=              Get Secret      mysecrets
    Log                     ${secret}[whowrotethis] wrote this program for you      console=yes


Directory Cleanup
    #make sure we have the necessary directories and empty them before starting
    Create Directory    ${receipt_directory}
    Create Directory    ${screenshot_directory}
    Create Directory    ${zip_directory}

    Empty Directory    ${receipt_directory}
    Empty Directory    ${screenshot_directory}
    Empty Directory    ${zip_directory}


Download csv file
    Download     ${csv_url}    overwrite=TRUE

Open the robot order website
    #Open the browser using the url variable
    Open Available Browser     ${url}

Fill out the form completely
    ${orders}=    Read table from CSV    path=orders.csv    header=true  
    FOR    ${order}    IN    @{orders}
        #fill out the form for one robot
        Fill out the form once    ${order}
        
        #Make screenshot and pdf receipt
        Make screenshot and receipt-pdf

        #Go back to starting page so you can place a new order
        Go Back to make new order
    END


Fill out the form once
    #we will loop this Keyword, so we need arguments 
    [Arguments]    ${orders}

    #Every order the pop-up will have to be clicked away
    Click Button    OK
    Wait Until Page Contains Element    head
    
    #fill out the necessary boxes
    Select From List By Index    head    ${orders}[Head]
    Select Radio Button    body    ${orders}[Body]
    Input Text    xpath://html/body/div/div/div[1]/div/div[1]/form/div[3]/input    ${orders}[Legs]
    Input Text    address    ${orders}[Address]
    
    #Click the preview button because we need to screenshot it later, then on order en then on order another robot
    Click Button    preview 

    #A sever error can occur here, so we need to try it until it succeeds
    Wait Until Keyword Succeeds    2min    1s    Submit Order

#need a seperate keyword to use 'wait until keyword succeeds'
Submit Order
    Click Button    order
    Page Should Contain Element    id:receipt   

Make screenshot and receipt-pdf
    #when we see the receipt, we get the order_number for the unique pdf filename
    Wait Until Element Is Visible    id:receipt
    ${order_id}=    Get Text    //*[@id="receipt"]/p[1]

    #make the pdf 
    Set Local Variable    ${receipt_filename}    ${receipt_directory}receipt_${order_id}.pdf
    ${receipt_html}=    Get Element Attribute    //*[@id="receipt"]    outerHTML
    Html To Pdf    content=${receipt_html}    output_path=${receipt_filename}
    
    #make the screenshot of the preview picture
    Wait Until Element Is Visible    id:robot-preview-image
    Set Local Variable    ${image_filename}    ${screenshot_directory}robot_${order_id}.png
    Screenshot    id:robot-preview-image    ${image_filename}
    
    #now combine the two
    Combine receipt with robot image to a PDF    ${receipt_filename}    ${image_filename}

Combine receipt with robot image to a PDF
    #we grab the two files to combine
    [Arguments]    ${receipt_filename}    ${image_filename}

    #open the pdf (of the receipt)
    #Open PDF    ${receipt_filename}

    #create the list to be added
    @{pseudo_file_list}=    Create List    ${image_filename}: x=0,y=0
    
    #add the list to the pdf file
    Add Files To PDF    ${pseudo_file_list}    ${receipt_filename}    ${True}

    #close the file
    #Close Pdf    ${receipt_filename}    


Go Back to make new order   
    Wait Until Element Is Visible    id:order-another
    Click Button    id:order-another

Make the zip file
    ${zip_file}=     Set Variable    ${zip_directory}/PDFs.zip    
    Archive Folder With Zip    ${receipt_directory}    ${zip_file}

Close the browser
    Close Browser


