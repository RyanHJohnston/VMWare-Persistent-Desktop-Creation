Add-Type -AssemblyName System.Windows.Forms

$form = New-Object System.Windows.Forms.Form
$form.Text = "Hello, PowerShell GUI!"
$form.Width = 400
$form.Height = 300

$button = New-Object System.Windows.Forms.Button
$button.Text = "Click Me"
$button.Top = 100
$button.Left = 150
$button.Add_Click({ [System.Windows.Forms.MessageBox]::Show("Hello World") })

$form.Controls.Add($button)
$form.ShowDialog()