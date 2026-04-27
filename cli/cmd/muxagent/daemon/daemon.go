package daemon

import "github.com/spf13/cobra"

func NewCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "daemon",
		Short: "Manage MuxAgent daemon",
	}

	cmd.AddCommand(newStartCmd())
	cmd.AddCommand(newStartSyncCmd())
	cmd.AddCommand(newEnsureCmd())
	cmd.AddCommand(newStopCmd())
	cmd.AddCommand(newStatusCmd())
	cmd.AddCommand(newEchoCmd())
	cmd.AddCommand(newAttachSessionCmd())

	return cmd
}
