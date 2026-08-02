Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

$xamlString = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows System Utility" Height="700" Width="1000"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="#202020" Foreground="#FFFFFF"
        FontFamily="Segoe UI Variable, Segoe UI, Arial">
    <Window.Resources>
        <!-- ScrollBar Style -->
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="Width" Value="8"/>
        </Style>
        
        <!-- Sidebar Button Style -->
        <Style x:Key="SidebarTabButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#E0E0E0"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Height" Value="40"/>
            <Setter Property="Margin" Value="10,2,10,2"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Padding" Value="12,0,0,0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                CornerRadius="4" BorderThickness="3,0,0,0" BorderBrush="Transparent">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#2A2A2A"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#333333"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Main Action Button Style -->
        <Style x:Key="ActionButton" TargetType="Button">
            <Setter Property="Background" Value="#2D2D2D"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#3D3D3D"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="15,8,15,8"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#353535"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#252525"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#1F1F1F"/>
                                <Setter Property="Foreground" Value="#666666"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Accent Button Style -->
        <Style x:Key="AccentButton" TargetType="Button" BasedOn="{StaticResource ActionButton}">
            <Setter Property="Background" Value="#005FB8"/>
            <Setter Property="BorderBrush" Value="#005FB8"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#0078D4"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#004A90"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </Style>

        <!-- Card Container Style -->
        <Style x:Key="CardBorder" TargetType="Border">
            <Setter Property="Background" Value="#272727"/>
            <Setter Property="BorderBrush" Value="#333333"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="6"/>
            <Setter Property="Padding" Value="20"/>
            <Setter Property="Margin" Value="0,0,0,12"/>
        </Style>
    </Window.Resources>
    
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="250"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        
        <!-- SIDEBAR -->
        <Grid Grid.Column="0" Background="#181818">
            <Grid.RowDefinitions>
                <RowDefinition Height="80"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="120"/>
            </Grid.RowDefinitions>
            
            <StackPanel Grid.Row="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="20,0,0,0">
                <TextBlock Text="&#xE713;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="22" VerticalAlignment="Center" Foreground="#0078D4"/>
                <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
                    <TextBlock Text="System Utility" FontWeight="SemiBold" FontSize="16" Foreground="#FFFFFF"/>
                    <TextBlock Text="Windows Optimization" FontSize="12" Foreground="#888888"/>
                </StackPanel>
            </StackPanel>
            
            <StackPanel Grid.Row="1" Margin="0,10,0,0">
                <Button Name="BtnTabDashboard" Style="{StaticResource SidebarTabButton}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE80F;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Margin="0,0,12,0" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock Text="Dashboard" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                <Button Name="BtnTabOptimizer" Style="{StaticResource SidebarTabButton}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xEC4A;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Margin="0,0,12,0" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock Text="Optimizer" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                <Button Name="BtnTabDisplayFix" Style="{StaticResource SidebarTabButton}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE7F4;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Margin="0,0,12,0" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock Text="Display Fix" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                <Button Name="BtnTabSecurityApps" Style="{StaticResource SidebarTabButton}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE773;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Margin="0,0,12,0" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock Text="Security &amp; Apps" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                <Button Name="BtnTabActivation" Style="{StaticResource SidebarTabButton}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE8D7;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Margin="0,0,12,0" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock Text="Windows Activation" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                <Button Name="BtnTabAbout" Style="{StaticResource SidebarTabButton}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE946;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Margin="0,0,12,0" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock Text="About &amp; Help" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
            </StackPanel>
            
            <Border Grid.Row="2" Background="#1C1C1C" BorderBrush="#252525" BorderThickness="0,1,0,0" Padding="20,15,20,15">
                <StackPanel VerticalAlignment="Center">
                    <TextBlock Text="SYSTEM RESOURCES" FontSize="10" FontWeight="SemiBold" Foreground="#666666" Margin="0,0,0,10"/>
                    <Grid Margin="0,0,0,4">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBlock Text="CPU Usage" FontSize="11" Foreground="#AAAAAA"/>
                        <TextBlock Name="LblCpuVal" Grid.Column="1" Text="0%" FontSize="11" FontWeight="SemiBold" Foreground="#0078D4"/>
                    </Grid>
                    <ProgressBar Name="ProgCpu" Height="2" Value="0" Maximum="100" Background="#333333" Foreground="#0078D4" BorderThickness="0"/>
                    
                    <Grid Margin="0,12,0,4">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBlock Text="Memory Usage" FontSize="11" Foreground="#AAAAAA"/>
                        <TextBlock Name="LblRamVal" Grid.Column="1" Text="0%" FontSize="11" FontWeight="SemiBold" Foreground="#0078D4"/>
                    </Grid>
                    <ProgressBar Name="ProgRam" Height="2" Value="0" Maximum="100" Background="#333333" Foreground="#0078D4" BorderThickness="0"/>
                </StackPanel>
            </Border>
        </Grid>
        
        <!-- MAIN CONTENT -->
        <Grid Grid.Column="1" Background="#202020">
            <Grid.RowDefinitions>
                <RowDefinition Height="*"/>
                <RowDefinition Height="180"/>
            </Grid.RowDefinitions>
            
            <Grid Grid.Row="0" Margin="30,30,30,0">
                <!-- TAB 1: DASHBOARD -->
                <Grid Name="PanelDashboard" Visibility="Visible">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,25">
                        <TextBlock Text="Dashboard" FontSize="26" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock Text="System overview and quick optimization tools." FontSize="13" Foreground="#AAAAAA" Margin="0,4,0,0"/>
                    </StackPanel>
                    
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Grid Margin="0,0,0,12">
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,6,0">
                                    <StackPanel>
                                        <TextBlock Text="Operating System" FontSize="12" Foreground="#888888" FontWeight="SemiBold"/>
                                        <TextBlock Name="LblOsName" Text="Windows 10/11" FontSize="16" FontWeight="SemiBold" Margin="0,10,0,4" TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Name="LblOsVersion" Text="Build Info" FontSize="12" Foreground="#888888"/>
                                    </StackPanel>
                                </Border>
                                <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="6,0,0,0">
                                    <StackPanel>
                                        <TextBlock Text="Privilege Level" FontSize="12" Foreground="#888888" FontWeight="SemiBold"/>
                                        <TextBlock Text="Administrator" FontSize="16" FontWeight="SemiBold" Foreground="#429CE3" Margin="0,10,0,4"/>
                                        <TextBlock Text="Full access granted" FontSize="12" Foreground="#888888"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                            
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="180"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center">
                                        <TextBlock Text="Quick Boost" FontSize="16" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                                        <TextBlock Text="Automatically creates a restore point, clears temporary files, and enables the Ultimate Performance power plan." FontSize="13" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,20,0"/>
                                    </StackPanel>
                                    <Button Name="BtnQuickBoost" Grid.Column="1" Style="{StaticResource AccentButton}" Content="Run Quick Boost" VerticalAlignment="Center" Height="36"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- TAB 2: OPTIMIZER -->
                <Grid Name="PanelOptimizer" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,25">
                        <TextBlock Text="Optimizer" FontSize="26" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Manage updates, power plans, and system storage." FontSize="13" Foreground="#AAAAAA" Margin="0,4,0,0"/>
                    </StackPanel>
                    
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="280"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,20,0">
                                        <TextBlock Text="Windows Update Control" FontSize="15" FontWeight="SemiBold"/>
                                        <TextBlock Text="Disable automatic updates to prevent unexpected restarts, or re-enable them when needed." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,0"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Right">
                                        <Button Name="BtnDisableWU" Style="{StaticResource ActionButton}" Content="Disable Updates" Width="130" Margin="0,0,10,0"/>
                                        <Button Name="BtnEnableWU"  Style="{StaticResource ActionButton}" Content="Enable Updates" Width="130"/>
                                    </StackPanel>
                                </Grid>
                            </Border>
                            
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,6,0">
                                    <StackPanel>
                                        <TextBlock Text="Temporary Files" FontSize="15" FontWeight="SemiBold"/>
                                        <TextBlock Text="Clear system temp and prefetch folders to free up disk space." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,15" Height="40"/>
                                        <Button Name="BtnCleanTemp" Style="{StaticResource ActionButton}" Content="Clean Temp Files" HorizontalAlignment="Left"/>
                                    </StackPanel>
                                </Border>
                                <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="6,0,0,0">
                                    <StackPanel>
                                        <TextBlock Text="Power Plan" FontSize="15" FontWeight="SemiBold"/>
                                        <TextBlock Text="Enable the hidden Ultimate Performance power plan for maximum hardware efficiency." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,15" Height="40"/>
                                        <Button Name="BtnUltimatePower" Style="{StaticResource ActionButton}" Content="Enable Power Plan" HorizontalAlignment="Left"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                            
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,20,0">
                                        <TextBlock Text="System Restore Point" FontSize="15" FontWeight="SemiBold"/>
                                        <TextBlock Text="Create a system restore point manually before making major changes to the system." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnCreateRestore" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Create Restore Point" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- TAB 3: DISPLAY FIX -->
                <Grid Name="PanelDisplayFix" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,25">
                        <TextBlock Text="Display Fix" FontSize="26" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Resolve display output issues and clear monitor cache." FontSize="13" Foreground="#AAAAAA" Margin="0,4,0,0"/>
                    </StackPanel>
                    
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,20,0">
                                        <TextBlock Text="Restart Graphics Driver" FontSize="15" FontWeight="SemiBold"/>
                                        <TextBlock Text="Restarts the display adapter and Desktop Window Manager (DWM). Useful for frozen screens or stuttering." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnResetGpu" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Restart Driver" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,20,0">
                                        <TextBlock Text="Clear Monitor Cache" FontSize="15" FontWeight="SemiBold"/>
                                        <TextBlock Text="Clears registry cache for external monitors. Forces Windows to redetect HDMI/DP connections." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnClearDispCache" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Clear Registry Cache" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- TAB 4: SECURITY & APPS -->
                <Grid Name="PanelSecurityApps" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,25">
                        <TextBlock Text="Security &amp; Apps" FontSize="26" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Scan for threats and remove pre-installed bloatware." FontSize="13" Foreground="#AAAAAA" Margin="0,4,0,0"/>
                    </StackPanel>
                    
                    <Grid Grid.Row="1">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="280"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                        
                        <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,10,12">
                            <StackPanel>
                                <TextBlock Text="Windows Defender" FontSize="15" FontWeight="SemiBold"/>
                                <TextBlock Text="Run a quick scan to ensure the system is free from active threats." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,20"/>
                                <Button Name="BtnDefenderScan" Style="{StaticResource ActionButton}" Content="Run Quick Scan" HorizontalAlignment="Left"/>
                            </StackPanel>
                        </Border>
                        
                        <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="2,0,0,12" Padding="20">
                            <Grid>
                                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                                <Grid Grid.Row="0" Margin="0,0,0,12">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                    <TextBlock Text="Select bloatware to remove:" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    <Button Name="BtnScanBloatware" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Scan Apps" FontSize="11" Padding="12,4,12,4"/>
                                </Grid>
                                
                                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,0,0,15">
                                    <StackPanel Name="StackBloatware" Margin="2,0,2,0"/>
                                </ScrollViewer>
                                
                                <Grid Grid.Row="2">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                    <TextBlock Name="LblBloatwareCount" Text="Click 'Scan Apps' to discover installed bloatware." FontSize="11" Foreground="#888888" VerticalAlignment="Center"/>
                                    <Button Name="BtnUninstallBloatware" Grid.Column="1" Style="{StaticResource AccentButton}" Content="Remove Selected"/>
                                </Grid>
                            </Grid>
                        </Border>
                    </Grid>
                </Grid>

                <!-- TAB 5: ACTIVATION -->
                <Grid Name="PanelActivation" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,25">
                        <TextBlock Text="Windows Activation" FontSize="26" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Permanently activate Windows using digital licensing." FontSize="13" Foreground="#AAAAAA" Margin="0,4,0,0"/>
                    </StackPanel>
                    
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Grid Margin="0,0,0,12">
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,6,0">
                                    <StackPanel>
                                        <TextBlock Text="Detected Edition" FontSize="12" Foreground="#888888" FontWeight="SemiBold"/>
                                        <TextBlock Name="LblActOsName" Text="Loading..." FontSize="16" FontWeight="SemiBold" Margin="0,10,0,4" TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Name="LblActOsVersion" Text="Build Info" FontSize="12" Foreground="#888888"/>
                                    </StackPanel>
                                </Border>
                                <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="6,0,0,0">
                                    <StackPanel>
                                        <TextBlock Text="License Status" FontSize="12" Foreground="#888888" FontWeight="SemiBold"/>
                                        <TextBlock Name="LblActStatus" Text="Checking..." FontSize="16" FontWeight="SemiBold" Foreground="#E3A742" Margin="0,10,0,4"/>
                                        <TextBlock Name="LblActMethod" Text="Method: Detecting..." FontSize="12" Foreground="#888888"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                            
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,20,0">
                                        <TextBlock Text="Run Activation Setup" FontSize="16" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                                        <TextBlock Text="Automatically determines the best method (HWID for Client, KMS for Server) and registers the license." FontSize="13" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnStartActivation" Grid.Column="1" Style="{StaticResource AccentButton}" Content="Activate Windows" VerticalAlignment="Center" Height="36"/>
                                </Grid>
                            </Border>
                            
                            <Border Style="{StaticResource CardBorder}">
                                <StackPanel>
                                    <TextBlock Text="Information" FontSize="13" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                    <TextBlock Text="HWID: Digital license permanently tied to hardware. Survives OS reinstallations." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,2,0,4"/>
                                    <TextBlock Text="KMS: Used for Server editions. Activates for 180 days and auto-renews." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,2,0,0"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- TAB 6: ABOUT -->
                <Grid Name="PanelAbout" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,25">
                        <TextBlock Text="About &amp; Help" FontSize="26" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Application information and usage guidelines." FontSize="13" Foreground="#AAAAAA" Margin="0,4,0,0"/>
                    </StackPanel>
                    
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Style="{StaticResource CardBorder}">
                                <StackPanel>
                                    <TextBlock Text="Windows System Utility v1.2" FontSize="16" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                                    <TextBlock Text="An open-source utility to optimize Windows, fix display issues, clean storage, and manage bloatware. Designed with native Fluent design principles." FontSize="13" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,8,0,15"/>
                                    <TextBlock Text="License: MIT (Free and Open Source)" FontSize="12" Foreground="#888888"/>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource CardBorder}">
                                <StackPanel>
                                    <TextBlock Text="Usage Guidelines" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                    <TextBlock Text="• Always create a Restore Point before applying major optimizations." FontSize="13" Foreground="#AAAAAA" Margin="0,3,0,3"/>
                                    <TextBlock Text="• Antivirus software might flag this utility due to registry modifications." FontSize="13" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,3,0,3"/>
                                    <TextBlock Text="• After applying the HDMI Fix, reconnect the monitor cable to force redetection." FontSize="13" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,3,0,3"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>
            </Grid>

            <!-- CONSOLE LOG PANEL -->
            <Border Grid.Row="1" Background="#181818" BorderBrush="#2A2A2A" BorderThickness="0,1,0,0" Padding="30,15,30,15">
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Grid Grid.Row="0" Margin="0,0,0,8">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBlock Name="LblStatus" Text="Ready." FontSize="12" FontWeight="SemiBold" Foreground="#CCCCCC"/>
                        <TextBlock Grid.Column="1" Text="Process Output" FontSize="11" Foreground="#666666"/>
                    </Grid>
                    
                    <TextBox Name="TxtConsole" Grid.Row="1" Background="#121212" Foreground="#CCCCCC"
                             BorderBrush="#252525" BorderThickness="1" Padding="10"
                             FontFamily="Consolas, Courier New, Monospace" FontSize="11"
                             IsReadOnly="True" VerticalScrollBarVisibility="Auto"
                             TextWrapping="Wrap" AcceptsReturn="True"/>
                             
                    <ProgressBar Name="ProgressMain" Grid.Row="2" Height="4" Margin="0,10,0,0"
                                 Background="#222222" Foreground="#0078D4" BorderThickness="0"
                                 IsIndeterminate="False" Value="0"/>
                </Grid>
            </Border>
        </Grid>
    </Grid>
</Window>
'@

try {
    $xml = [xml]$xamlString
    Write-Output "Parsing XML: Success"
    
    # Actually test XamlReader parse (Requires WPF which is not available in pwsh on linux, but we can just check if XML parsing fails)
} catch {
    Write-Output "Parsing XML: Failed"
    Write-Output $_.Exception.Message
}
